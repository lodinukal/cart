const Self = @This();

pub const Error = File.Error;

pub const VTable = struct {
    open_file_impl: *const fn (ctx: ?*anyopaque, path: []const u8, flags: File.Flags) File.Error!File,
    close_file_impl: *const fn (ctx: ?*anyopaque, file: File) void,
    delete_file_impl: *const fn (ctx: ?*anyopaque, path: []const u8) File.Error!void,
    file_exists_impl: *const fn (ctx: ?*anyopaque, path: []const u8) bool,
    file_reader_impl: *const fn (ctx: ?*anyopaque, file: File) File.Error!std.fs.File.Reader,
    file_writer_impl: *const fn (ctx: ?*anyopaque, file: File) File.Error!std.fs.File.Writer,
    file_set_readonly_impl: *const fn (ctx: ?*anyopaque, file: File, readonly: bool) File.Error!void,
    file_get_readonly_impl: *const fn (ctx: ?*anyopaque, file: File) bool,
    file_get_permissions_impl: *const fn (ctx: ?*anyopaque, file: File, class: Class) Permissions,
    file_set_permissions_impl: *const fn (ctx: ?*anyopaque, file: File, class: Class, permissions: Permissions) File.Error!void,
};

vtable: *const VTable,
context: ?*anyopaque,

pub inline fn openFile(self: Self, path: []const u8, flags: File.Flags) File.Error!File {
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
        AccessDenied,
        SharingViolation,
        Unknown,
    };
    pub const Flags = struct {
        mode: std.fs.File.OpenMode = .read_only,
        lock: std.fs.File.Lock = .none,
        create_if_not_exists: bool = true,
        truncate_if_exists: bool = false,
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

const std = @import("std");
const builtin = @import("builtin");

pub const Native = @import("platforms/Native.zig");
// pub const Wasm = @import("platforms/Wasm.zig");
