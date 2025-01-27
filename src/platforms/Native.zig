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
    const metadata = (platformFileToNativeFile(file).metadata() catch |err| switch (err) {
        error.AccessDenied => return true,
        else => std.debug.panic("fileGetReadonly: unexpected error {}", .{err}),
    });
    return metadata.permissions().readOnly();
}

pub fn fileSetReadonly(_: ?*anyopaque, file: File, readonly: bool) File.Error!void {
    const native_file = platformFileToNativeFile(file);
    var permissions = std.mem.zeroes(std.fs.File.Permissions);
    permissions.setReadOnly(!readonly);
    std.log.info("setting readonly: {}", .{readonly});
    native_file.setPermissions(permissions) catch |err| switch (err) {
        error.AccessDenied => return error.AccessDenied,
        else => return error.Unknown,
    };
}

pub fn fileSetPermissions(_: ?*anyopaque, file: File, class: Platform.Class, permissions: Platform.Permissions) File.Error!void {
    const native_file = platformFileToNativeFile(file);
    switch (builtin.os.tag) {
        .windows => {
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

const std = @import("std");
const builtin = @import("builtin");

const Platform = @import("../Platform.zig");
const File = Platform.File;
