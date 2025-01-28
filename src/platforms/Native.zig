const Self = @This();

const vtable: Platform.VTable = .{
    .open_file_impl = openFile,
    .close_file_impl = closeFile,
    .delete_file_impl = deleteFile,
    .file_exists_impl = fileExists,
    .file_reader_impl = fileReader,
    .file_writer_impl = fileWriter,
    // .file_get_permissions_impl: *const fn (ctx: ?*anyopaque, file: File) Permissions,
    // .file_set_permissions_impl: *const fn (ctx: ?*anyopaque, file: File, permissions: Permissions) File.Error!void,
    .file_get_readonly_impl = fileGetReadonly,
    .file_set_readonly_impl = fileSetReadonly,
    .file_get_permissions_impl = fileGetPermissions,
    .file_set_permissions_impl = fileSetPermissions,

    .create_client_impl = createClient,
    .destroy_client_impl = destroyClient,
    .client_request_impl = clientRequest,
    .request_status_impl = requestStatus,
    .destroy_request_impl = destroyRequest,
};

pub fn platform() Platform {
    return .{
        .vtable = &vtable,
        .context = null,
    };
}

pub fn openFile(_: ?*anyopaque, path: []const u8, flags: File.Flags) File.Error!File {
    if (flags.truncate_if_exists) {
        return createFile(path, flags);
    }
    return nativeFileToPlatformFile(std.fs.cwd().openFile(path, .{
        .mode = flags.mode,
        .lock = flags.lock,
    }) catch |err| switch (err) {
        error.FileNotFound => {
            if (flags.create_if_not_exists) {
                return createFile(path, flags);
            } else {
                return error.FileNotFound;
            }
        },
        error.AccessDenied => return error.AccessDenied,
        error.SharingViolation => return error.SharingViolation,
        else => return error.Unknown,
    });
}

fn createFile(path: []const u8, flags: File.Flags) File.Error!File {
    const file = std.fs.cwd().createFile(path, .{
        .read = switch (flags.mode) {
            .read_only => true,
            .write_only => false,
            .read_write => false,
        },
        .lock = flags.lock,
    }) catch |err| switch (err) {
        error.PathAlreadyExists => unreachable,
        error.AccessDenied => return error.AccessDenied,
        error.SharingViolation => return error.SharingViolation,
        else => return error.Unknown,
    };
    return nativeFileToPlatformFile(file);
}

pub fn closeFile(_: ?*anyopaque, file: File) void {
    platformFileToNativeFile(file).close();
}

pub fn deleteFile(_: ?*anyopaque, path: []const u8) File.Error!void {
    std.fs.cwd().deleteFile(path) catch |err| switch (err) {
        error.FileNotFound => return error.FileNotFound,
        error.AccessDenied => return error.AccessDenied,
        else => return error.Unknown,
    };
}

pub fn fileExists(_: ?*anyopaque, path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => return false,
        error.AccessDenied => return true,
        error.SharingViolation => return true,
        else => return false,
    };
    defer file.close();
    return true;
}

pub fn fileReader(_: ?*anyopaque, file: File) File.Error!std.fs.File.Reader {
    return platformFileToNativeFile(file).reader();
}

pub fn fileWriter(_: ?*anyopaque, file: File) File.Error!std.fs.File.Writer {
    return platformFileToNativeFile(file).writer();
}

pub fn fileGetReadonly(_: ?*anyopaque, file: File) bool {
    switch (builtin.os.tag) {
        .wasi => {
            return false;
        },
        else => {
            const metadata = (platformFileToNativeFile(file).metadata() catch |err| switch (err) {
                error.AccessDenied => return true,
                else => std.debug.panic("fileGetReadonly: unexpected error {}", .{err}),
            });
            return metadata.permissions().readOnly();
        },
    }
}

pub fn fileSetReadonly(_: ?*anyopaque, file: File, readonly: bool) File.Error!void {
    const native_file = platformFileToNativeFile(file);
    var permissions = std.mem.zeroes(std.fs.File.Permissions);
    permissions.setReadOnly(!readonly);
    std.log.info("setting readonly: {}", .{readonly});
    switch (builtin.os.tag) {
        .wasi => {
            // noop
        },
        else => {
            native_file.setPermissions(permissions) catch |err| switch (err) {
                error.AccessDenied => return error.AccessDenied,
                else => return error.Unknown,
            };
        },
    }
}

pub fn fileSetPermissions(_: ?*anyopaque, file: File, class: Platform.Class, permissions: Platform.Permissions) File.Error!void {
    const native_file = platformFileToNativeFile(file);
    switch (builtin.os.tag) {
        .windows => {
            // noop
        },
        .wasi => {
            // noop
        },
        else => {
            var native_permissions: std.fs.File.Permissions = .{};
            native_permissions.inner.unixSet(class, .{
                .read = permissions.read,
                .write = permissions.write,
                .execute = permissions.execute,
            });
            native_file.setPermissions(native_permissions);
        },
    }
}

pub fn fileGetPermissions(_: ?*anyopaque, file: File, class: Platform.Class) Platform.Permissions {
    const native_file = platformFileToNativeFile(file);
    switch (builtin.os.tag) {
        .windows => {
            return .{};
        },
        .wasi => {
            // noop
            return .{};
        },
        else => {
            const metadata = (native_file.metadata() catch return .{});
            return .{
                .read = metadata.permissions().inner.unixHas(class, .read),
                .write = metadata.permissions().inner.unixHas(class, .write),
                .execute = metadata.permissions().inner.unixHas(class, .execute),
            };
        },
    }
}

pub fn platformFileToNativeFile(file: File) std.fs.File {
    const zig_file_handle: *const std.fs.File.Handle = @ptrCast(&file);
    return .{
        .handle = zig_file_handle.*,
    };
}

pub fn nativeFileToPlatformFile(file: std.fs.File) File {
    const handle = file.handle;
    const handle_ptr: *const File = @ptrCast(&handle);
    return handle_ptr.*;
}

// networking

const NativeHttpClient = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    client: if (!is_wasm) std.http.Client else void,
};

pub fn createClient(_: ?*anyopaque, allocator: std.mem.Allocator) HttpClient.Error!HttpClient {
    const self = try allocator.create(NativeHttpClient);
    self.allocator = allocator;
    self.arena = std.heap.ArenaAllocator.init(allocator);
    if (!is_wasm) {
        self.client = .{ .allocator = self.arena.allocator() };
    }
    return .{
        .platform = platform(),
        .handle = @intFromPtr(self),
    };
}

pub fn destroyClient(_: ?*anyopaque, client: HttpClient) void {
    const self: *NativeHttpClient = @ptrFromInt(client.handle);
    if (!is_wasm) {
        self.client.deinit();
    }
    self.arena.deinit();
    self.allocator.destroy(self);
}

const NativeRequest = struct {
    pub const Impl = if (is_wasm) struct {
        data: ?[]const u8 = null,
        fbs: std.io.FixedBufferStream([]const u8) = .{ .buffer = &.{}, .pos = 0 },

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            if (self.data) |d|
                allocator.free(d);
        }
    } else struct {
        reader: std.http.Client.Request.Reader = undefined,
        request: std.http.Client.Request,

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.request.deinit();
        }
    };

    allocator: std.mem.Allocator,
    impl: Impl,
    status: Request.Status = .pending,
    done: std.atomic.Value(bool) = .init(false),

    /// called only on non-wasm
    pub fn spawn(self: *NativeRequest) void {
        self.impl.request.wait() catch |err| {
            self.status = .{ .err = err };
            self.done.store(true, .release);
            return;
        };
        self.impl.reader = self.impl.request.reader();
        self.status = .{ .ready = self.impl.reader.any() };
        self.done.store(true, .release);
    }

    pub fn deinit(self: *NativeRequest) void {
        self.impl.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

extern fn cart_fetch(url_ptr: [*]const u8, url_len: usize, context: usize) callconv(.C) void;

fn cart_on_fetched_success(context: usize, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    const self: *NativeRequest = @ptrFromInt(context);
    self.impl.data = self.allocator.dupe(u8, data_ptr[0..data_len]) catch @panic("out of memory");
    self.impl.fbs = .{ .buffer = self.impl.data.?, .pos = 0 };
    self.status = .{ .ready = self.impl.fbs.reader().any() };
    self.done.store(true, .release);
}

fn cart_on_fetched_error(context: usize) callconv(.C) void {
    const self: *NativeRequest = @ptrFromInt(context);
    self.status = .{ .err = error.Unknown };
    self.done.store(true, .release);
}

// only used on wasm
fn cart_alloc(size: usize) callconv(.C) ?[*]const u8 {
    return (std.heap.wasm_allocator.alloc(u8, size) catch return null).ptr;
}

// only used on wasm
fn cart_free(ptr: [*]const u8, len: usize) callconv(.C) void {
    std.heap.wasm_allocator.free(ptr[0..len]);
}

comptime {
    if (is_wasm) {
        @export(&cart_on_fetched_success, .{
            .name = "cart_on_fetched_success",
        });
        @export(&cart_on_fetched_error, .{
            .name = "cart_on_fetched_error",
        });

        @export(&cart_alloc, .{
            .name = "cart_alloc",
        });
        @export(&cart_free, .{
            .name = "cart_free",
        });
    }
}

pub fn clientRequest(
    _: ?*anyopaque,
    client: HttpClient,
    method: std.http.Method,
    path: []const u8,
    options: std.http.Client.RequestOptions,
) Request.Error!Request {
    const self: *NativeHttpClient = @ptrFromInt(client.handle);
    const request = try self.allocator.create(NativeRequest);
    if (is_wasm) {
        request.* = .{
            .allocator = self.allocator,
            .impl = .{},
        };
        cart_fetch(path.ptr, path.len, @intFromPtr(request));
    } else {
        const uri = std.Uri.parse(path) catch return error.InvalidUri;

        request.* = .{
            .allocator = self.allocator,
            .impl = .{
                .request = try self.client.open(method, uri, options),
            },
        };
        try request.impl.request.send();

        const thread = std.Thread.spawn(.{
            .stack_size = 1024,
            .allocator = self.allocator,
        }, NativeRequest.spawn, .{request}) catch return error.OutOfMemory;
        thread.detach();
    }

    return .{
        .client = client,
        .handle = @intFromPtr(request),
    };
}

pub fn requestStatus(_: ?*anyopaque, request: Request) Request.Status {
    const self: *NativeRequest = @ptrFromInt(request.handle);
    if (!self.done.load(.acquire)) {
        return .pending;
    }
    return self.status;
}

pub fn destroyRequest(_: ?*anyopaque, request: Request) void {
    const self: *NativeRequest = @ptrFromInt(request.handle);
    self.deinit();
}

const std = @import("std");
const builtin = @import("builtin");

const is_wasm = builtin.object_format == .wasm;

const Platform = @import("../Platform.zig");
const File = Platform.File;
const HttpClient = Platform.HttpClient;
const Request = Platform.Request;
