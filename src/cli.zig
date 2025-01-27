pub fn main() !void {
    const is_wasm = builtin.target.os.tag == .wasi or (builtin.target.os.tag == .freestanding and builtin.target.ofmt == .wasm);
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (is_wasm) std.heap.wasm_allocator else general_purpose_allocator.allocator();
    defer if (!is_wasm) {
        _ = general_purpose_allocator.deinit();
    };

    const plat = lib.Platform.Native.platform();
    const luaurc_file = try plat.openFile(".luaurc", .{ .mode = .read_only, .create_if_not_exists = false });
    defer plat.closeFile(luaurc_file);

    const luaurc_contents = (try luaurc_file.reader(plat))
        .readAllAlloc(allocator, std.math.maxInt(u16)) catch return error.OutOfMemory;
    defer allocator.free(luaurc_contents);

    var luaurc = try lib.luaurc.Config.parse(allocator, allocator, luaurc_contents);
    defer luaurc.deinit();

    var context: lib.Context = .{
        .rc = luaurc,
        .allocator = allocator,
        .platform = plat,
        .options = .{
            .temp = .{},
            .require = .{},
            .scheduler = .{ .err_fn = luau_error_fn },
        },
    };
    try context.init();
    defer context.deinit();
    try context.loadCartStandard();

    var arg_it = try std.process.argsWithAllocator(allocator);
    defer arg_it.deinit();
    // skip executable name
    _ = arg_it.next();
    const file_name = arg_it.next() orelse {
        std.log.err("expected file name", .{});
        return error.MissingArgument;
    };

    const thread = try context.loadThreadFromFile(file_name);
    try context.execute(thread);

    // not wasm
    var start_time: f64 = @floatFromInt(std.time.milliTimestamp());
    context.temp.nextFrame();
    while (!context.isWorkDone()) {
        const current_time: f64 = @floatFromInt(std.time.milliTimestamp());
        context.delta_time = (current_time - start_time) / 1000.0;
        start_time = current_time;
        try context.poll();
        context.temp.nextFrame();
        // context.main_state.gcCollect();
    }
}

fn luau_error_fn(err: []const u8) void {
    std.log.err("{s}", .{err});
}

const std = @import("std");
const builtin = @import("builtin");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("cart_lib");

const luau = @import("luau");
