test "example.luau" {
    _ = try runTest("cases/example.luau", .{});
}

test "get_os.luau" {
    _ = try runTest("cases/get_os.luau", .{
        .enabled_modules = .{
            .sys = true,
        },
        .runtime = .{
            .extra_aliases = &.{
                cart.require.preloadedKVComptime("cart"),
            },
        },
    });
}

test "simple_fs.luau" {
    _ = try runTest("cases/simple_fs.luau", .{
        .enabled_modules = .{
            .fs = true,
        },
        .runtime = .{
            .extra_aliases = &.{
                cart.require.preloadedKVComptime("cart"),
            },
        },
    });
}

test "fuzz_fs.luau" {
    _ = try runTest("cases/fuzz_fs.luau", .{
        .enabled_modules = .{
            .fs = true,
        },
        .runtime = .{
            .extra_aliases = &.{
                cart.require.preloadedKVComptime("cart"),
            },
        },
    });
}

test "simple_ast.luau" {
    _ = try runTest("cases/simple_ast.luau", .{
        .enabled_modules = .{
            .ast = true,
        },
        .runtime = .{
            .extra_aliases = &.{
                cart.require.preloadedKVComptime("cart"),
            },
        },
    });
}

pub const Config = struct {
    runtime: cart.Context.Config = .{},
    enabled_modules: struct {
        ast: bool = false,
        sys: bool = false,
        fs: bool = false,
        pretty: bool = true,
    } = .{},
};

pub fn runTest(comptime case: []const u8, config: Config) !*cart.Context {
    const allocator = std.testing.allocator;
    const context: *cart.Context = try cart.Context.create(allocator, config.runtime);
    defer context.destroy();
    const l = context.state;

    const code = @embedFile(case);
    const compiled = try cart.luau.compile(
        allocator,
        allocator,
        code,
        context.compile_options,
    );
    defer compiled.deinit(allocator);
    try std.testing.expect(l.load("@" ++ case, compiled.bytes));

    l.pushFunction(testlog, "testlog");
    l.setGlobal("testlog");

    if (config.enabled_modules.sys) {
        try cart.modules.sys.open(context);
    }
    if (config.enabled_modules.fs) {
        try cart.modules.fs.open(context);
    }
    if (config.enabled_modules.pretty) {
        try cart.modules.pretty.open(context);
    }
    if (config.enabled_modules.ast) {
        try cart.modules.ast.open(context);
    }

    if (l.pcall(0, 0, .none) != .ok) {
        if (l.isString(.at(-1))) {
            const string = l.toLengthString(.at(-1));
            if (std.mem.eql(u8, string, "SKIPTEST")) {
                return error.SkipZigTest;
            }
            std.log.err("{s}", .{string});
        } else {
            std.log.err("Unknown error", .{});
        }
        const debug_trace = l.debugTrace();
        if (debug_trace.len > 0)
            std.log.err("{s}", .{debug_trace});
        return error.TestFailed;
    }

    return context;
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
