pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    const plat = lib.Platform.Native.platform();
    const http_client = try plat.createClient(allocator);
    lib.Context.modules.net.setClient(http_client);

    const luaurc_contents = if (plat.fileExists(".luaurc")) blk: {
        const luaurc_file = try plat.openFile(".luaurc", .{ .mode = .read_only, .create_if_not_exists = false });
        defer plat.closeFile(luaurc_file);

        break :blk (try luaurc_file.reader(plat))
            .readAllAlloc(allocator, std.math.maxInt(u16)) catch return error.OutOfMemory;
    } else 
    \\ { "languageMode": "strict" }
    ;
    const luaurc = try lib.luaurc.Config.parse(allocator, allocator, luaurc_contents);

    cli_state = .{
        .allocator = allocator,
        .platform = plat,
        .http_client = http_client,
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
    defer cli_state.deinit();

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

    var start_time: f64 = @floatFromInt(std.time.milliTimestamp());
    while (!cli_state.context.isWorkDone()) {
        const current_time: f64 = @floatFromInt(std.time.milliTimestamp());
        const delta = (current_time - start_time) / 1000.0;
        start_time = current_time;
        if (!step(delta)) break;
    }
}

const CliState = struct {
    allocator: std.mem.Allocator,
    platform: lib.Platform,
    http_client: lib.Platform.HttpClient,
    luaurc_contents: []const u8,
    luaurc: lib.luaurc.Config,
    context: lib.Context,

    pub fn deinit(self: *CliState) void {
        self.allocator.free(self.luaurc_contents);
        self.luaurc.deinit();
        self.context.deinit();

        self.http_client.destroy();
    }
};
var cli_state: CliState = undefined;

pub fn step(delta: f64) callconv(.c) bool {
    cli_state.context.delta_time = delta;
    cli_state.context.poll() catch return !cli_state.context.isWorkDone();
    cli_state.context.temp.nextFrame();
    cli_state.context.main_state.gcCollect();
    return !cli_state.context.isWorkDone();
}

fn luau_error_fn(err: []const u8) void {
    std.log.err("{s}", .{err});
}

const std = @import("std");
const builtin = @import("builtin");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("cart_lib");

const luau = @import("luau");
