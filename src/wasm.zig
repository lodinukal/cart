pub fn main() !void {
    const allocator = std.heap.wasm_allocator;

    const plat = lib.Platform.Native.platform();
    const http_client = try plat.createClient(allocator);
    lib.Context.modules.net.setClient(http_client);

    const luaurc = try lib.luaurc.Config.parse(allocator, allocator,
        \\ { "languageMode": "strict" }
    );

    cli_state = .{
        .allocator = allocator,
        .platform = plat,
        .http_client = http_client,
        .luaurc = luaurc,
        .context = .{
            .rc = luaurc,
            .allocator = allocator,
            .platform = plat,
            .options = .{
                .temp = .{},
                .require = .{
                    .custom_require_handler = customIncludeHandler,
                },
                .scheduler = .{ .err_fn = luau_error_fn },
            },
        },
    };
    try cli_state.context.init();
    try cli_state.context.loadCartStandard();
}

const CliState = struct {
    allocator: std.mem.Allocator,
    platform: lib.Platform,
    http_client: lib.Platform.HttpClient,
    luaurc: lib.luaurc.Config,
    context: lib.Context,

    pub fn deinit(self: *CliState) void {
        self.luaurc.deinit();
        self.context.deinit();

        self.http_client.destroy();
    }
};
var cli_state: CliState = undefined;

var last_wasm_error: ?anyerror = null;
pub fn popLastError() callconv(.c) ?[*:0]const u8 {
    if (last_wasm_error == null) {
        return null;
    }
    defer last_wasm_error = null;
    return @errorName(last_wasm_error.?);
}

const WasmThreadHandle = enum(u32) { null = 0, _ };

pub fn loadThreadFromFile(name_ptr: [*]const u8, name_len: usize) callconv(.c) WasmThreadHandle {
    const name = name_ptr[0..name_len];
    const thread = cli_state.context.loadThreadFromFile(name) catch |e| {
        last_wasm_error = e;
        return .null;
    };
    return @enumFromInt(@intFromPtr(thread));
}

pub fn loadThreadFromString(
    path_ptr: [*]const u8,
    path_len: usize,
    src_ptr: [*]const u8,
    src_len: usize,
) callconv(.c) WasmThreadHandle {
    const path = path_ptr[0..path_len];
    const src = src_ptr[0..src_len];

    const thread = cli_state.context.loadThreadFromString(path, src) catch |e| {
        last_wasm_error = e;
        return .null;
    };
    return @enumFromInt(@intFromPtr(thread));
}

pub fn closeThread(handle: WasmThreadHandle) callconv(.c) void {
    if (handle == .null) {
        return;
    }
    const l: *luau.Luau = @ptrFromInt(@as(usize, @intCast(@intFromEnum(handle))));
    l.close();
}

pub fn executeThread(handle: WasmThreadHandle) callconv(.c) bool {
    if (handle == .null) {
        return false;
    }
    const l: *luau.Luau = @ptrFromInt(@as(usize, @intCast(@intFromEnum(handle))));
    cli_state.context.execute(l) catch |e| {
        last_wasm_error = e;
        return false;
    };
    return true;
}

pub fn threadIsScheduled(handle: WasmThreadHandle) callconv(.c) bool {
    if (handle == .null) {
        return false;
    }
    const l: *luau.Luau = @ptrFromInt(@as(usize, @intCast(@intFromEnum(handle))));
    for (cli_state.context.scheduler.working.items) |item| {
        if (item.state == l) {
            return true;
        }
    }
    for (cli_state.context.scheduler.waiting.items) |item| {
        if (item.state == l) {
            return true;
        }
    }
    return false;
}

pub fn threadStatus(handle: WasmThreadHandle) callconv(.c) u8 {
    if (handle == .null) {
        return 0;
    }
    const l: *luau.Luau = @ptrFromInt(@as(usize, @intCast(@intFromEnum(handle))));
    return @intFromEnum(l.status());
}

extern fn cart_require_handler(
    path_ptr: [*]const u8,
    path_len: usize,
    resolved_source_ptr: [*]const u8,
    resolved_source_len: usize,
    out_len: *usize,
) ?[*]const u8;

fn customIncludeHandler(l: *luau.Luau, path: []const u8, resolved_source: []const u8) ?[]const u8 {
    const context = lib.Context.getContext(l) orelse return null;
    var len: usize = 0;
    const result = cart_require_handler(
        path.ptr,
        path.len,
        resolved_source.ptr,
        resolved_source.len,
        &len,
    );
    if (result == null) {
        return null;
    }
    const slice = result.?[0..len];
    // defer std.heap.wasm_allocator.free(slice);
    return context.temp.allocator().dupe(u8, slice) catch return null;
}

pub fn step(delta: f64) callconv(.c) bool {
    cli_state.context.delta_time = delta;
    cli_state.context.poll() catch return true;
    cli_state.context.temp.nextFrame();
    cli_state.context.main_state.gcCollect();
    return true;
}

pub fn end() callconv(.c) void {
    cli_state.deinit();
}

comptime {
    @export(&popLastError, .{ .name = "cart_popLastError" });
    @export(&loadThreadFromFile, .{ .name = "cart_loadThreadFromFile" });
    @export(&loadThreadFromString, .{ .name = "cart_loadThreadFromString" });
    @export(&closeThread, .{ .name = "cart_closeThread" });
    @export(&executeThread, .{ .name = "cart_executeThread" });
    @export(&threadIsScheduled, .{ .name = "cart_threadIsScheduled" });
    @export(&threadStatus, .{ .name = "cart_threadStatus" });
    @export(&step, .{ .name = "cart_step" });
    @export(&end, .{ .name = "cart_end" });
}

fn luau_error_fn(err: []const u8) void {
    std.log.err("{s}", .{err});
}

const std = @import("std");
const builtin = @import("builtin");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("cart_lib");

const luau = @import("luau");
