pub fn open(l: *luau.Luau) void {
    l.newTable();

    l.pushString("get_os");
    l.pushFunction(lGetOs, "@cart/sys.get_os");
    l.setTable(-3);

    l.pushString("argv");
    l.pushFunction(lArgv, "@cart/sys.argv");
    l.setTable(-3);

    l.pushString("getenv");
    l.pushFunction(lGetenv, "@cart/sys.getenv");
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

fn lArgv(l: *luau.Luau) !i32 {
    var args_it = try std.process.argsWithAllocator(l.allocator());
    defer args_it.deinit();

    l.newTable();

    var index: i32 = 1;
    while (args_it.next()) |arg| {
        l.pushString(arg);
        l.rawSetIndex(-2, index);
        index += 1;
    }

    return 1;
}

fn lGetenv(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const key = l.checkString(1);
    const lallocator = l.allocator();
    const t = context.temp.allocator();
    if (try std.process.hasEnvVar(lallocator, key)) {
        const temp = try std.process.getEnvVarOwned(lallocator, key);
        defer lallocator.free(temp);

        const duped = t.dupeZ(u8, temp) catch return 0;
        defer t.free(duped);
        l.pushString(duped);
    } else {
        l.pushNil();
    }
    return 1;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
