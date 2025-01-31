pub fn open(l: *luau.Luau) void {
    l.newTable();

    l.pushString("wait");
    l.pushFunction(lWait, "@cart/task.wait");
    l.setTable(-3);

    l.pushString("spawn");
    l.pushFunction(lSpawn, "@cart/task.spawn");
    l.setTable(-3);

    l.pushString("cancel");
    l.pushFunction(lCancel, "@cart/task.cancel");
    l.setTable(-3);

    l.pushString("defer");
    l.pushFunction(lDefer, "@cart/task.defer");
    l.setTable(-3);

    l.pushString("delay");
    l.pushFunction(lDelay, "@cart/task.delay");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

fn lWait(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const time_wait = if (l.getTop() < 1) 0.0 else try l.toNumber(1);
    try context.scheduler.schedule(try Scheduler.Thread.init(.time(time_wait), l, l));
    return l.yield(1);
}

/// converts a thread or function at the index to a thread
///
/// pushes to the top of the stack
fn toThread(l: *luau.Luau, index: i32) *luau.Luau {
    const type_ = l.typeOf(index);
    if (type_ == .thread) {
        l.pushValue(index);
        return l.toThread(index) catch @panic("error converting to thread");
    }
    if (type_ != .function) {
        l.argError(index, "function or thread expected");
    }
    const t = l.newThread();
    l.xPush(t, index);

    return t;
}

fn lCancel(l: *luau.Luau) i32 {
    const context = Context.getContext(l) orelse return 0;
    if (!l.isThread(1)) {
        l.argError(1, "thread expected");
    }
    const thread = l.toThread(1) catch @panic("error converting to thread");

    for (context.scheduler.waiting.items) |*t| {
        if (t.state == thread) {
            t.cancelled = true;
            return 0;
        }
    }

    return l.raiseErrorFmt("thread not found", .{}) catch unreachable;
}

fn lSpawn(l: *luau.Luau) !i32 {
    const type_1 = l.typeOf(1);
    if (type_1 != .function and type_1 != .thread) {
        l.argError(1, "function or thread expected");
    }

    const thread = toThread(l, 1);

    const top = l.getTop();
    const arg_length = top - 1;

    for (0..@intCast(arg_length)) |n| {
        // +1 for arg
        // +1 to offset from thread
        l.xPush(thread, @intCast(n + 2));
    }

    _ = resumeCatch(l, thread, arg_length);

    return 1;
}

fn lDefer(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const type_1 = l.typeOf(1);
    if (type_1 != .function and type_1 != .thread) {
        l.argError(1, "function or thread expected");
    }
    const thread = toThread(l, 1);
    const top = l.getTop();
    const arg_length = top - 1;
    for (0..@intCast(arg_length)) |n| {
        // +1 for arg
        // +1 to offset from thread
        l.xPush(thread, @intCast(n + 2));
    }
    try context.scheduler.schedule(try Scheduler.Thread.init(.time(0.0), thread, l));
    return 1;
}

fn lDelay(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const delay: f64 = switch (l.typeOf(1)) {
        .nil => 0.0,
        .number => l.checkNumber(1),
        else => l.argError(1, "number or nil expected"),
    };

    const type_2 = l.typeOf(2);
    if (type_2 != .function and type_2 != .thread) {
        l.argError(1, "function or thread expected");
    }

    const thread = toThread(l, 2);

    const top = l.getTop();
    const arg_length = top - 2;

    for (0..@intCast(arg_length)) |n| {
        // +1 for arg
        // +1 to offset from thread
        // +1 to offset from delay
        l.xPush(thread, @intCast(n + 3));
    }

    try context.scheduler.schedule(try Scheduler.Thread.init(.time(delay), thread, l));

    return 1;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
const resumeCatch = Scheduler.resumeCatch;
