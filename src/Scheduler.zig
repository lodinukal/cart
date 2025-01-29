const Self = @This();

/// scheduler specific errors
pub const Error = error{
    /// the scheduler has run out of memory to allocate a new thread
    OutOfMemory,
    /// failure to reference a thread
    LuauRef,
};

/// allocator must be set before calling `init`
allocator: std.mem.Allocator,
/// see `Options`
options: Options,

/// the main luau state
main_state: *luau.Luau,

/// do not write to this, it is the set of threads that are currently
/// being processed by the scheduler
working: Queue = .{},
/// this is ok to write to, it is the set of threads that are waiting to be processed
/// by the scheduler
waiting: Queue = .{},

pub const DEFAULT_INITIAL_THREAD_COUNT: u16 = 8;

pub const Options = struct {
    /// the number of initial threads to be created in the queues
    ///
    /// will ignore the `bounded` option if this is set
    preallocate: u16 = DEFAULT_INITIAL_THREAD_COUNT,
    /// if no more threads can be added to the queues
    ///
    /// this is recommended to be set to prevent the scheduler from using too much memory
    bounded: bool = false,
    /// a function to catch errors thrown by the lua c functions
    ///
    /// do not store err directly, dupe them if needed
    err_fn: *const fn (err: []const u8) void,
};

pub fn init(self: *Self) Error!void {
    self.* = .{
        .allocator = self.allocator,
        .options = self.options,
        .main_state = self.main_state,

        .working = try std.ArrayListUnmanaged(Thread).initCapacity(self.allocator, self.options.preallocate),
        .waiting = try std.ArrayListUnmanaged(Thread).initCapacity(self.allocator, self.options.preallocate),
    };
}

pub fn deinit(self: *Self) void {
    self.working.deinit(self.allocator);
    self.waiting.deinit(self.allocator);
}

/// adds a thread to the scheduler
pub fn schedule(self: *Self, thread: Thread) Error!void {
    if (self.options.bounded and self.waiting.unusedCapacitySlice().len == 0) return error.OutOfMemory;
    try self.waiting.append(self.allocator, thread);
}

/// call this function to poll the threads
pub fn poll(self: *Self, cart_context: *CartContext) Error!void {
    defer {
        std.mem.swap(Queue, &self.working, &self.waiting);
    }
    for (self.working.items) |*thread| {
        var keeping = false;

        scope: {
            if (thread.cancelled) {
                break :scope;
            }
            const from = from: {
                if (thread.parent) |parent| {
                    break :from parent.state;
                }
                break :from self.main_state;
            };
            const result: ResumeCatchResult = result: switch (thread.condition) {
                .poll_ => |p| switch (p.poll_fn(p.context, thread, cart_context)) {
                    .ready_ => |arg_count| {
                        break :result resumeCatch(from, thread.state, arg_count);
                    },
                    .pending => {
                        keeping = true;
                        break :scope;
                    },
                    .err => {
                        break :result .{
                            .err = thread.state.toString(-1) catch "unknown error",
                        };
                    },
                },
                .time_ => |*t| {
                    t.time_left -= cart_context.delta_time;
                    if (t.time_left <= 0.0) {
                        thread.state.pushNumber(t.original_time - t.time_left);
                        break :result resumeCatch(from, thread.state, 1);
                    }
                    keeping = true;
                    break :scope;
                },
                .instant => {
                    break :result resumeCatch(from, thread.state, 0);
                },
            };

            switch (result) {
                .err => |err| {
                    keeping = false;
                    self.options.err_fn(err);
                },
                else => {},
            }
        }

        if (keeping) {
            try self.schedule(thread.*);
        } else {
            // dereferencing the thread
            if (thread.parent) |parent| {
                self.main_state.unref(parent.ref);
            }
        }
    }

    self.working.clearRetainingCapacity();
}

/// returned by a lua c function to the scheduler so that it can be resumed when ready
pub const Poll = union(enum) {
    ready_: i32,
    pending,
    err,

    pub inline fn ready(arg_count: i32) Poll {
        return .{ .ready_ = arg_count };
    }
};

/// context is the same as the one passed to the scheduler
///
/// the thread should not be stored, it has a lifetime of one poll
pub const PollFn = *const fn (context: ?*anyopaque, thread: *const Thread, cart_context: *CartContext) Poll;

pub const ThreadCondition = union(enum) {
    poll_: struct {
        /// context passed to the polling function
        context: ?*anyopaque,
        /// function to call when the thread is attempted to be resumed
        ///
        /// a .pending value returned will keep the thread in the scheduler while a .ready_ value will
        /// remove the thread from the scheduler and resume it with the number of arguments specified
        poll_fn: PollFn,
    },
    time_: struct {
        /// the time to wait in seconds
        time_left: f64,
        /// the original time to wait in seconds
        original_time: f64,
    },
    instant,

    pub inline fn poll(comptime Context: type, ctx: *Context) ThreadCondition {
        return .{ .poll_ = .{
            .context = @ptrCast(ctx),
            .poll_fn = @ptrCast(&Context.poll),
        } };
    }

    pub inline fn time(t: f64) ThreadCondition {
        return .{ .time_ = .{ .time_left = t, .original_time = t } };
    }

    pub inline fn fence() ThreadCondition {
        return .{ .thread_ = .{ .value = .init(false) } };
    }
};

/// stores state about a scheduler thread
pub const Thread = struct {
    /// `Poll` should have a `poll` method that looks like `PollFn`
    pub fn init(cond: ThreadCondition, state: *luau.Luau, from: ?*luau.Luau) Error!Thread {
        return .{
            .condition = cond,
            .state = state,
            .parent = blk: {
                const main = state.getMainThread();
                if (from == null) break :blk .{
                    .state = main,
                };
                // pushThread returns true if the thread is the main thread of its state
                // so we dont need to ref it
                if (state.pushThread()) {
                    state.pop(1);
                    break :blk .{
                        .state = main,
                    };
                } else {
                    state.xMove(main, 1);
                    const ref = main.ref(-1) catch return error.LuauRef;
                    main.pop(1);
                    break :blk .{
                        .state = from.?,
                        .ref = ref,
                    };
                }
            },
        };
    }

    condition: ThreadCondition,
    /// the state of the thread
    state: *luau.Luau,
    /// see `Parent`, can be null if the thread is the main thread
    parent: ?Parent = null,
    /// a value that can be toggled to remove the thread from the scheduler on the next poll
    cancelled: bool = false,

    pub const Parent = struct {
        /// the calling thread
        state: *luau.Luau,
        /// a reference to prevent the parent from being garbage collected
        ref: i32 = 0,
    };
};

/// a list of threads to be resumed
pub const Queue = std.ArrayListUnmanaged(Thread);

pub const ResumeCatchResult = union(enum) {
    ok,
    yield,
    @"break",
    /// do not store err, dupe them if needed
    err: []const u8,
};

/// utility function
pub fn resumeCatch(from: *luau.Luau, state: *luau.Luau, arg_count: i32) ResumeCatchResult {
    return switch (state.resumeThread(from, arg_count) catch {
        return .{ .err = state.toString(-1) catch "unknown error" };
    }) {
        inline else => |status| @unionInit(ResumeCatchResult, @tagName(status), {}),
    };
}

const std = @import("std");
const luau = @import("luau");

const config = @import("config");

const CartContext = @import("Context.zig");
