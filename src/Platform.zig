const Self = @This();

pub const Error = File.Error || Request.Error || HttpClient.Error;

pub const VTable = struct {
    create_file_impl: *const fn (ctx: ?*anyopaque, path: []const u8, flags: File.CreateFlags) File.Error!File,
    open_file_impl: *const fn (ctx: ?*anyopaque, path: []const u8, flags: File.OpenFlags) File.Error!File,
    close_file_impl: *const fn (ctx: ?*anyopaque, file: File) void,
    delete_file_impl: *const fn (ctx: ?*anyopaque, path: []const u8) File.Error!void,
    file_exists_impl: *const fn (ctx: ?*anyopaque, path: []const u8) bool,
    file_reader_impl: *const fn (ctx: ?*anyopaque, file: File) File.Error!std.fs.File.Reader,
    file_writer_impl: *const fn (ctx: ?*anyopaque, file: File) File.Error!std.fs.File.Writer,
    file_set_readonly_impl: *const fn (ctx: ?*anyopaque, file: File, readonly: bool) File.Error!void,
    file_get_readonly_impl: *const fn (ctx: ?*anyopaque, file: File) bool,
    file_get_permissions_impl: *const fn (ctx: ?*anyopaque, file: File, class: Class) Permissions,
    file_set_permissions_impl: *const fn (ctx: ?*anyopaque, file: File, class: Class, permissions: Permissions) File.Error!void,

    create_client_impl: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator) HttpClient.Error!HttpClient,
    destroy_client_impl: *const fn (ctx: ?*anyopaque, client: HttpClient) void,
    client_request_impl: *const fn (
        ctx: ?*anyopaque,
        client: HttpClient,
        method: std.http.Method,
        path: []const u8,
        options: std.http.Client.RequestOptions,
    ) Request.Error!Request,
    request_status_impl: *const fn (ctx: ?*anyopaque, request: Request) Request.Status,
    destroy_request_impl: *const fn (ctx: ?*anyopaque, request: Request) void,
};

vtable: *const VTable,
context: ?*anyopaque,

pub inline fn createFile(self: Self, path: []const u8, flags: File.CreateFlags) File.Error!File {
    return self.vtable.create_file_impl(self.context, path, flags);
}

pub inline fn openFile(self: Self, path: []const u8, flags: File.OpenFlags) File.Error!File {
    return self.vtable.open_file_impl(self.context, path, flags);
}

pub inline fn closeFile(self: Self, file: File) void {
    return self.vtable.close_file_impl(self.context, file);
}

pub inline fn deleteFile(self: Self, path: []const u8) File.Error!void {
    return self.vtable.delete_file_impl(self.context, path);
}

pub inline fn fileExists(self: Self, path: []const u8) bool {
    return self.vtable.file_exists_impl(self.context, path);
}

pub inline fn createClient(self: Self, allocator: std.mem.Allocator) HttpClient.Error!HttpClient {
    return self.vtable.create_client_impl(self.context, allocator);
}

pub const Class = std.fs.File.PermissionsUnix.Class;

pub const Permissions = struct {
    read: ?bool = null,
    write: ?bool = null,
    execute: ?bool = null,
};

pub const File = struct {
    handle: usize,

    pub const Error = error{
        FileNotFound,
        PathAlreadyExists,
        AccessDenied,
        SharingViolation,
        Unknown,
    };

    pub const CreateFlags = struct {
        mode: std.fs.File.OpenMode = .read_only,
        lock: std.fs.File.Lock = .none,
        exclusive: bool = false,
        truncate_if_exists: bool = false,
    };

    pub const OpenFlags = struct {
        mode: std.fs.File.OpenMode = .read_only,
        lock: std.fs.File.Lock = .none,
        create_if_not_exists: bool = true,
    };

    pub inline fn reader(self: File, platform: Self) File.Error!std.fs.File.Reader {
        return platform.vtable.file_reader_impl(platform.context, self);
    }

    pub inline fn writer(self: File, platform: Self) File.Error!std.fs.File.Writer {
        return platform.vtable.file_writer_impl(platform.context, self);
    }

    pub inline fn setReadonly(self: File, platform: Self, readonly: bool) File.Error!void {
        return platform.vtable.file_set_readonly_impl(platform.context, self, readonly);
    }

    pub inline fn getReadonly(self: File, platform: Self) bool {
        return platform.vtable.file_get_readonly_impl(platform.context, self);
    }

    /// valid on posix
    pub inline fn getPermissions(self: File, class: Class, platform: Self) Permissions {
        return platform.vtable.file_get_permissions_impl(platform.context, self, class);
    }

    /// valid on posix
    pub inline fn setPermissions(self: File, platform: Self, class: Class, permissions: Permissions) File.Error!void {
        return platform.vtable.file_set_permissions_impl(platform.context, self, class, permissions);
    }
};

pub const Request = struct {
    pub const Error = std.http.Client.RequestError ||
        std.http.Client.Request.SendError ||
        std.http.Client.Request.WaitError ||
        HttpClient.Error || error{ InvalidUri, Unknown };

    pub const Status = union(enum) {
        ready: std.io.AnyReader,
        err: Request.Error,
        pending,
    };

    client: HttpClient,
    handle: usize,

    pub inline fn status(self: Request) Status {
        return self.client.platform.vtable.request_status_impl(self.client.platform.context, self);
    }

    pub inline fn destroy(self: Request) void {
        return self.client.platform.vtable.destroy_request_impl(self.client.platform.context, self);
    }
};

pub const HttpClient = struct {
    pub const Error = error{
        Unsupported,
        OutOfMemory,
    };

    platform: Self,
    handle: usize,

    pub fn request(
        self: HttpClient,
        method: std.http.Method,
        path: []const u8,
        options: std.http.Client.RequestOptions,
    ) Request.Error!Request {
        return self.platform.vtable.client_request_impl(self.platform.context, self, method, path, options);
    }

    pub fn destroy(self: HttpClient) void {
        return self.platform.vtable.destroy_client_impl(self.platform.context, self);
    }
};

const std = @import("std");
const builtin = @import("builtin");

pub const Native = @import("platforms/Native.zig");
// pub const Wasm = @import("platforms/Wasm.zig");

pub const is_wasm = builtin.object_format == .wasm;
