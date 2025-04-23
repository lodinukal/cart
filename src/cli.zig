var debug_allocator: std.heap.DebugAllocator(.{}) = .{};
pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer {
        if (is_debug) _ = debug_allocator.deinit();
    }

    const context: *cart.Context = try .create(gpa, .{
        .extra_aliases = &.{
            cart.require.preloadedKVComptime("test_caching"),
        },
    });
    defer context.destroy();
    const l = context.state;

    l.pushLengthString("should be cached!");
    try context.putCache("test_caching", .at(-1));

    const code =
        \\print("Hello, world!")
        \\assert(1 == 1)
        \\local cached = require("@test_caching")
    ;

    const compiled = try cart.luau.compile(
        gpa,
        gpa,
        code,
        context.compile_options,
    );
    defer compiled.deinit(gpa);

    try std.testing.expect(l.load("@test.luau", compiled.bytes));
    if (l.pcall(0, 0, .none) != .ok) {
        if (l.isString(.at(-1))) {
            std.debug.print("Error: {s}\n", .{l.toLengthString(.at(-1))});
        } else {
            std.debug.print("Unknown error\n", .{});
        }
    }
}

const std = @import("std");
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const cart = @import("cart");
