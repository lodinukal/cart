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
        .extra_aliases = &.{},
    });
    defer context.destroy();
    const l = context.state;

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    if (!args.skip()) return;

    const file_name = args.next() orelse return error.NoFileSpecified;
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const code = try file.readToEndAlloc(gpa, std.math.maxInt(usize));
    defer gpa.free(code);

    try cart.modules.sys.open(context);
    try cart.modules.fs.open(context);
    try cart.modules.pretty.open(context);
    try cart.modules.stream.open(context);
    try cart.modules.ast.open(context);
    try cart.modules.result.open(context);

    const compiled = try cart.luau.compile(
        gpa,
        gpa,
        code,
        context.compile_options,
    );
    defer compiled.deinit(gpa);

    const chunk_name = try std.fmt.allocPrintZ(gpa, "@{s}", .{file_name});
    defer gpa.free(chunk_name);

    try std.testing.expect(l.load(chunk_name, compiled.bytes));
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
