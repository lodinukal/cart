pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (is_wasm) std.heap.wasm_allocator else general_purpose_allocator.allocator();
    defer if (!is_wasm) {
        _ = general_purpose_allocator.deinit();
    };

    const plat = lib.Platform.Native.platform();
    const luaurc_file = try plat.openFile(".luaurc", .{ .mode = .read_only, .create_if_not_exists = false });

    const luaurc_contents = (try luaurc_file.reader(plat))
        .readAllAlloc(allocator, std.math.maxInt(u16)) catch return error.OutOfMemory;

    const luaurc = try lib.luaurc.Config.parse(allocator, allocator, luaurc_contents);

    cli_state = .{
        .allocator = allocator,
        .platform = plat,
        .luaurc_file = luaurc_file,
        .luaurc_contents = luaurc_contents,
        .luaurc = luaurc,
        .context = .{
            .rc = luaurc,
            .allocator = allocator,
            .platform = plat,
            .options = .{
                .temp = .{},
                .require = .{},
                .scheduler = .{ .err_fn = luau_error_fn },
            },
        },
    };
    try cli_state.context.init();
    try cli_state.context.loadCartStandard();

    var arg_it = try std.process.argsWithAllocator(allocator);
    defer arg_it.deinit();
    // skip executable name
    _ = arg_it.next();
    const file_name = arg_it.next() orelse {
        std.log.err("expected file name", .{});
        return error.MissingArgument;
    };

    const thread = try cli_state.context.loadThreadFromFile(file_name);
    try cli_state.context.execute(thread);
    cli_state.context.temp.nextFrame();

    if (!is_wasm) {
        var start_time: f64 = @floatFromInt(std.time.milliTimestamp());
        while (!cli_state.context.isWorkDone()) {
            const current_time: f64 = @floatFromInt(std.time.milliTimestamp());
            cli_state.context.delta_time = (current_time - start_time) / 1000.0;
            start_time = current_time;
            if (!step()) break;
        }
    }
}

const CliState = struct {
    allocator: std.mem.Allocator,
    platform: lib.Platform,
    luaurc_file: lib.Platform.File,
    luaurc_contents: []const u8,
    luaurc: lib.luaurc.Config,
    context: lib.Context,

    pub fn deinit(self: *CliState) void {
        self.allocator.free(self.luaurc_contents);
        self.platform.closeFile(self.luaurc_file);
        self.luaurc.deinit();
        self.context.deinit();
    }
};
var cli_state: CliState = undefined;

pub fn step(delta: f32) callconv(.c) bool {
    cli_state.context.delta_time = delta;
    cli_state.context.poll() catch return !cli_state.context.isWorkDone();
    cli_state.context.temp.nextFrame();
    cli_state.context.main_state.gcCollect();
    return !cli_state.context.isWorkDone();
}

pub fn end() callconv(.c) void {
    cli_state.deinit();
}

comptime {
    if (is_wasm) {
        @export(&step, .{
            .name = "step",
        });
        @export(&end, .{
            .name = "end",
        });
    }
}

fn luau_error_fn(err: []const u8) void {
    std.log.err("{s}", .{err});
}

const std = @import("std");
const builtin = @import("builtin");
const is_wasm = builtin.target.os.tag == .wasi or (builtin.target.os.tag == .freestanding and builtin.target.ofmt == .wasm);

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("cart_lib");

const luau = @import("luau");
