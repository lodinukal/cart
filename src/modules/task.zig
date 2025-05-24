pub fn push(context: *cart.Context) !void {
    const l = context.state;
    l.createPushTable(.{
        .@"defer" = @"defer",
    }, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/task");
    try push(context);
    luau.require.registermodule(context.state);
}

const ResumeThreadAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    thread_ref: luau.vm.Ref = .no,

    pub fn callback(
        opt_self: ?*ResumeThreadAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.Result,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.allocator.destroy(self);
        self.l.unref(self.thread_ref);
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

// like yield but it will resume the current thread later
fn @"defer"(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

    _ = l.pushThread();
    const ref = l.ref(.at(-1));
    l.pop(1);

    const future = try allocator.create(ResumeThreadAsync);
    future.* = .{
        .allocator = allocator,
        .completion = .{},
        .context = context,
        .l = l,
        .thread_ref = ref,
    };

    context.loop.add(&future.completion);
    return l.yield(0);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const xev = @import("xev");
