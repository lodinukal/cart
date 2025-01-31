pub fn open(l: *luau.Luau) void {
    l.newTable();

    l.pushString("get_os");
    l.pushFunction(lGetOs, "@cart/sys.get_os");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

fn lGetOs(l: *luau.Luau) !i32 {
    switch (@import("builtin").os.tag) {
        .windows => l.pushString("windows"),
        .macos => l.pushString("macos"),
        .linux => switch (@import("builtin").abi) {
            .android, .androideabi => l.pushString("android"),
            else => l.pushString("linux"),
        },
        .wasi => l.pushString("wasi"),
        .ios => l.pushString("ios"),
        else => l.pushString("unknown"),
    }
    return 1;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
