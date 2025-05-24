test "example.luau" {
    const context = try runTest("cases/example.luau", .{});
    context.destroy();
}

test "get_os.luau" {
    const context = try runTest("cases/get_os.luau", .{
        .enabled_modules = .{
            .sys = true,
        },
        .runtime = .{},
    });
    context.destroy();
}

test "simple_fs.luau" {
    const context = try runTest("cases/simple_fs.luau", .{
        .enabled_modules = .{
            .fs = true,
        },
        .runtime = .{},
    });
    context.destroy();
}

test "simple_net.luau" {
    const context = try runTest("cases/simple_fs.luau", .{
        .enabled_modules = .{
            .fs = true,
            .net = true,
        },
        .runtime = .{},
    });
    context.destroy();
}

test "fuzz_fs.luau" {
    const context = try runTest("cases/fuzz_fs.luau", .{
        .enabled_modules = .{
            .fs = true,
        },
        .runtime = .{},
    });
    context.destroy();
}

test "simple_ast.luau" {
    const context = try runTest("cases/simple_ast.luau", .{
        .enabled_modules = .{
            .ast = true,
        },
        .runtime = .{},
    });
    context.destroy();
}

test "simple_stream.luau" {
    // test returns a reader which has "Hello, world!" in it
    const context = try runTest("cases/simple_stream.luau", .{
        .enabled_modules = .{
            .fs = true,
        },
        .runtime = .{},
    });
    defer context.destroy();
    const l = context.state;
    // test returns a reader
    const stream = cart.modules.stream;
    try std.testing.expect(stream.conformsto(l, .at(1), .reader));
    l.pop(1);
    const read_buffer = l.newBuffer(5);
    const read_result = stream.read(l, .at(1), .at(-1));
    std.testing.expect(read_result == .ok) catch |err| {
        std.log.err("Error reading stream: {s}", .{read_result.err.explanation});
        return err;
    };
    try std.testing.expectEqualSlices(u8, read_buffer.constSlice(), "Hello");

    // test returns a seekable reader
    try std.testing.expect(stream.isseekable(l, .at(1)) == .ok);
    const seek_result = stream.seek(l, .at(1), 0);
    std.testing.expect(seek_result == .ok) catch |err| {
        std.log.err("Error seeking stream: {s}", .{seek_result.err.explanation});
        return err;
    };

    const tell_result = stream.tell(l, .at(1));
    std.testing.expect(tell_result == .ok) catch |err| {
        std.log.err("Error telling stream: {s}", .{tell_result.err.explanation});
        return err;
    };
    std.testing.expect(tell_result.ok == 0) catch |err| {
        std.log.err("Error telling stream: {s}", .{tell_result.err.explanation});
        return err;
    };
}

pub const Config = struct {
    runtime: cart.Context.Config = .{},
    enabled_modules: struct {
        ast: bool = false,
        sys: bool = false,
        fs: bool = false,
        net: bool = false,
        stream: bool = true,
        pretty: bool = true,
        result: bool = true,
        task: bool = true,
    } = .{},
};

pub fn runTest(comptime case: []const u8, config: Config) !*cart.Context {
    const allocator = std.testing.allocator;
    const context: *cart.Context = try cart.Context.create(allocator, config.runtime);
    errdefer context.destroy();
    const l = context.state;
    defer _ = l.gc(.collect);

    // l.pushFunction(testlog, "testlog");
    l.pushClosurek(.init(testlog, "testlog"), 0);
    l.setGlobal("testlog");

    if (config.enabled_modules.sys) {
        try cart.modules.sys.open(context);
    }
    if (config.enabled_modules.fs) {
        try cart.modules.fs.open(context);
    }
    if (config.enabled_modules.net) {
        try cart.modules.net.open(context);
    }
    if (config.enabled_modules.pretty) {
        try cart.modules.pretty.open(context);
    }
    if (config.enabled_modules.stream) {
        try cart.modules.stream.open(context);
    }
    if (config.enabled_modules.ast) {
        try cart.modules.ast.open(context);
    }
    if (config.enabled_modules.result) {
        try cart.modules.result.open(context);
    }
    if (config.enabled_modules.task) {
        try cart.modules.task.open(context);
    }

    const code = @embedFile(case);
    const compiled = try cart.luau.compile(
        allocator,
        allocator,
        code,
        context.compile_options,
    );
    defer compiled.deinit(allocator);
    try std.testing.expect(l.load("@" ++ case, compiled.bytes));

    const res = l.@"resume"(null, 0);
    switch (res) {
        .suspended => {},
        .running => {},
        else => {
            testErr(l);
        },
    }

    while (!context.loop.done()) {
        // try context.run();
        try context.loop.run(.once);

        const status = l.status();
        switch (status) {
            .yield => continue,
            .ok => continue,
            else => {},
        }

        // error
        testErr(l);
    }

    return context;
}

fn testErr(l: *cart.luau.State) noreturn {
    const err_string = l.toLengthString(.at(-1));
    std.debug.print("Error: {s}\n", .{err_string});
    std.debug.print("stacktrace:\n{s}\n", .{l.debugTrace()});
    std.process.exit(1);
}

fn testlog(l: *cart.luau.State) void {
    const arg_count = l.getTop().int();
    const stderr = std.io.getStdErr().writer();

    stderr.print("LOG({d}) ", .{arg_count}) catch {};
    for (0..@as(usize, @intCast(arg_count))) |i| {
        const arg = cart.util.tostring(l, .at(@intCast(i + 1)));
        stderr.writeAll(arg) catch {};
        if (i != arg_count - 1) {
            stderr.writeAll(" ") catch {};
        }
    }
    stderr.writeAll("\n") catch {};
}

const std = @import("std");
const cart = @import("cart");

const test_scope = std.log.scoped(.@"cart test");
