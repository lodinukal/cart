pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/fs")) return;
    const l = context.state;
    l.createPushTable(.{
        .openfile = openFileHandled,
        .createfile = createFileHandled,
        .closefile = closeFileHandled,
        .makepath = makePathHandled,
        .delete = deleteHandled,
        .writefile = writeFileHandled,
        .appendfile = appendFileHandled,
        .readfile = readFileHandled,
        .abspath = absPath,
        .relpath = relPath,
        .tell = tell,
        .seek = seekHandled,
        .seekend = seekEndHandled,
        .kind = kind,
        .kindpath = kindPath,
        .lock = lockHandled,
        .trylock = tryLockHandled,
        .unlock = unlockHandled,
        .symlinkfile = symLinkFileHandled,
        .symlinkdir = symLinkDirHandled,
        .hardlinkfile = hardLinkFileHandled,
        .hardlinkdir = hardLinkDirHandled,
        .isreadonly = isReadOnlyHandled,
        .setreadonly = setReadOnlyHandled,
    }, null);
    l.setReadonly(.at(-1), true);
    try context.putCache("cart/fs", .at(-1));
    l.pop(1);

    try l.newMetatable(file_metatable);
    l.pushTable(.at(-1), .{
        .__type = file_metatable,
        .__metatable = "This metatable is locked",
        .__tostring = fileToString,
    }, null);
    l.setReadonly(.at(-1), true);
    l.pop(1);
}

pub const Error = error{
    InvalidState,
    InvalidArgument,
    NotImplemented,
    NotAFile,
    InvalidFile,
    FileNotFound,
    PathAlreadyExists,
    AccessDenied,
    SharingViolation,
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    DeviceBusy,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,
    LockViolation,
    WouldBlock,
    ConnectionResetByPeer,
    ProcessNotFound,
    NoDevice,
    NameTooLong,
    NotDir,
    SymLinkLoop,
    IsDir,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    BadPathName,
    PipeBusy,
    InvalidWtf8,
    NetworkNotFound,
    AntivirusInterference,
    InvalidUtf8,
    FileLocksNotSupported,
    FileBusy,
    Unseekable,
    Filesystem,
    UnrecognizedVolume,
    NotSupported,
    FileSystem,
    ReadOnlyFileSystem,
    LinkQuotaExceeded,
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,
    Canceled,
    DirNotEmpty,
    NotSameFileSystem,
    PermissionDenied,
    MessageTooBig,
    OutOfMemory,
    Unexpected,
};

pub fn errorName(err: Error) []const u8 {
    return switch (err) {
        error.InvalidState => return "invalid program state",
        error.InvalidArgument => return "invalid argument",
        error.NotImplemented => return "not implemented",
        error.NotAFile => return "not a file",
        error.InvalidFile => return "invalid file",
        error.FileNotFound => return "file was not found",
        error.PathAlreadyExists => return "path already exists",
        error.AccessDenied => return "access denied",
        error.SharingViolation => return "sharing violation",
        error.OutOfMemory => return "out of memory",
        error.DiskQuota => return "disk quota exceeded",
        error.FileTooBig => return "file too big",
        error.InputOutput => return "input/output error",
        error.NoSpaceLeft => return "no space left on device",
        error.DeviceBusy => return "device busy",
        error.BrokenPipe => return "broken pipe",
        error.SystemResources => return "system resources exhausted",
        error.OperationAborted => return "operation aborted",
        error.NotOpenForWriting => return "not open for writing",
        error.LockViolation => return "lock violation",
        error.WouldBlock => return "operation would block",
        error.ConnectionResetByPeer => return "connection reset by peer",
        error.ProcessNotFound => return "process not found",
        error.NoDevice => return "no such device",
        error.Unexpected => return "unexpected error",
        error.NameTooLong => return "name too long",
        error.NotDir => return "not a directory",
        error.SymLinkLoop => return "symbolic link loop",
        error.IsDir => return "is a directory",
        error.ProcessFdQuotaExceeded => return "process file descriptor quota exceeded",
        error.SystemFdQuotaExceeded => return "system file descriptor quota exceeded",
        error.BadPathName => return "bad path name",
        error.PipeBusy => return "pipe busy",
        error.InvalidWtf8 => return "invalid wtf-8",
        error.NetworkNotFound => return "network not found",
        error.AntivirusInterference => return "antivirus interference",
        error.InvalidUtf8 => return "invalid utf-8",
        error.FileLocksNotSupported => return "file locks not supported",
        error.FileBusy => return "file busy",
        error.Unseekable => return "unseekable",
        error.Filesystem => return "filesystem error",
        error.UnrecognizedVolume => return "unrecognized volume",
        error.NotSupported => return "not supported",
        error.FileSystem => return "filesystem error",
        error.ReadOnlyFileSystem => return "read-only filesystem",
        error.LinkQuotaExceeded => return "link quota exceeded",
        error.ConnectionTimedOut => return "connection timed out",
        error.NotOpenForReading => return "not open for reading",
        error.SocketNotConnected => return "socket not connected",
        error.Canceled => return "operation canceled",
        error.DirNotEmpty => return "directory not empty",
        error.NotSameFileSystem => return "not same filesystem",
        error.PermissionDenied => return "permission denied",
        error.MessageTooBig => return "message too big",
    };
}

pub const ErrorPayload = []const u8;

pub const file_metatable = "cart/fs/file";

pub const File = struct {
    /// luacase version
    pub const OpenMode = enum {
        readonly,
        writeonly,
        readwrite,

        pub fn toStd(self: OpenMode) std.fs.File.OpenMode {
            return switch (self) {
                .readonly => .read_only,
                .writeonly => .write_only,
                .readwrite => .read_write,
            };
        }
    };

    /// luacase version
    pub const Kind = enum {
        blockdevice,
        characterdevice,
        directory,
        namedpipe,
        symlink,
        file,
        unixdomainsocket,
        whiteout,
        door,
        eventport,
        unknown,

        pub fn fromStd(self: std.fs.File.Kind) Kind {
            return switch (self) {
                .block_device => .blockdevice,
                .character_device => .characterdevice,
                .directory => .directory,
                .named_pipe => .namedpipe,
                .sym_link => .symlink,
                .file => .file,
                .unix_domain_socket => .unixdomainsocket,
                .whiteout => .whiteout,
                .door => .door,
                .event_port => .eventport,
                else => unreachable,
            };
        }
    };

    pub const CreateFlags = struct {
        mode: std.fs.File.OpenMode = .read_only,
        lock: std.fs.File.Lock = .none,
        exclusive: bool = false,
        truncate: bool = false,
    };

    pub const OpenFlags = struct {
        mode: std.fs.File.OpenMode = .read_only,
        lock: std.fs.File.Lock = .none,
        create: bool = true,
    };

    allocator: std.mem.Allocator,
    valid: bool = true,
    file: std.fs.File,
    /// storing path because zig fs discourages using realpath
    path: [:0]u8,

    current_lock: std.fs.File.Lock = .none,

    pub fn push(l: *luau.State, file: std.fs.File, path: []const u8) !*File {
        const allocator = l.allocator();
        const new_file: *File = @alignCast(@ptrCast(l.newUserdataDtor(
            @sizeOf(File),
            @ptrCast(&fileDtor),
        ) orelse
            return error.OutOfMemory));
        _ = l.getMetatableRegistry(file_metatable);
        l.setMetatable(.at(-2));
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const canoncial_path = try allocator.dupeZ(
            u8,
            try std.fs.realpath(path, buf[0..]),
        );
        new_file.* = .{
            .file = file,
            .allocator = allocator,
            .valid = true,
            .path = canoncial_path,
        };
        return new_file;
    }

    pub fn to(l: *luau.State, at: luau.vm.Index) !*File {
        const file: *File = @alignCast(@ptrCast(l.checkUserdata(at, file_metatable) orelse return error.NotAFile));
        if (!file.valid) return error.InvalidFile;
        return file;
    }
};

fn fileDtor(file: *File) callconv(.c) void {
    if (file.valid) {
        file.file.close();
        file.allocator.free(file.path);
        file.valid = false;
    }
}

fn openFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        openFile(l, &diagnostics),
        &diagnostics,
    );
}

fn openFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));
    const flags = try parseOpenFlags(l, .at(2), diagnostics);
    const std_flags: std.fs.File.OpenFlags = .{
        .mode = flags.mode,
        .lock = flags.lock,
    };

    const opened = context.cwd.openFile(path, std_flags) catch |err| blk: {
        if (err == error.FileNotFound and flags.create) {
            const create_flags: std.fs.File.CreateFlags = .{
                .lock = flags.lock,
                .exclusive = false,
                .read = true,
            };
            const created = context.cwd.createFile(path, create_flags) catch |create_err| {
                if (diagnostics) |diag| {
                    diag.push("Failed to create file `{s}` because {s}", .{ path, errorName(create_err) }) catch {};
                }
                return create_err;
            };
            break :blk created;
        }
        if (diagnostics) |diag| {
            diag.push("Failed to open file `{s}` because {s}", .{ path, errorName(err) }) catch {};
        }
        return err;
    };

    const file = try File.push(l, opened, path);
    file.current_lock = flags.lock;
    return .at(-1);
}

fn createFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        createFile(l, &diagnostics),
        &diagnostics,
    );
}

fn createFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));
    const flags = try parseCreateFlags(l, .at(2), diagnostics);
    const std_flags: std.fs.File.CreateFlags = .{
        .read = flags.mode != .write_only,
        .lock = flags.lock,
        .exclusive = true,
        .truncate = flags.truncate,
    };

    const created = context.cwd.createFile(path, std_flags) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create file `{s}` because {s}", .{ path, errorName(err) }) catch {};
        }
        return err;
    };

    const file = try File.push(l, created, path);
    file.current_lock = flags.lock;
    return .at(-1);
}

fn closeFileHandled(l: *luau.State) i32 {
    return cart.util.returnValue(l, bool, closeFile(l));
}

fn closeFile(l: *luau.State) bool {
    const file: *File = File.to(l, .at(1)) catch return false;
    fileDtor(file);
    return true;
}

fn makePathHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        makePath(l, &diagnostics),
        &diagnostics,
    );
}

fn makePath(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));
    context.cwd.makePath(path) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create directories `{s}` because {s}", .{ path, errorName(err) }) catch {};
        }
        return err;
    };
}

fn deleteHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        delete(l, &diagnostics),
        &diagnostics,
    );
}

fn delete(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));

    std.fs.Dir.deleteTree(context.cwd, path) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to delete directories `{s}` because {s}", .{ path, errorName(err) }) catch {};
        }
        return err;
    };
}

fn writeFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        writeFile(l, &diagnostics),
        &diagnostics,
    );
}

fn writeFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const file: *File = try .to(l, .at(1));
    const contents: []const u8 = blk: {
        switch (l.type(.at(2))) {
            .string => break :blk l.toLengthString(.at(2)),
            .buffer => break :blk l.toBuffer(.at(2)).constSlice(),
            else => {
                if (diagnostics) |diag| {
                    diag.push("Invalid write argument type `{s}`", .{@tagName(l.type(.at(1)))}) catch {};
                }
                return error.InvalidArgument;
            },
        }
    };
    file.file.seekTo(0) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to seek file `{s}` to beginning because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
    file.file.writeAll(contents) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to write file `{s}` because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
}

fn appendFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        appendFile(l, &diagnostics),
        &diagnostics,
    );
}

fn appendFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const file: *File = try .to(l, .at(1));
    const contents: []const u8 = blk: {
        switch (l.type(.at(2))) {
            .string => break :blk l.toLengthString(.at(2)),
            .buffer => break :blk l.toBuffer(.at(2)).constSlice(),
            else => {
                if (diagnostics) |diag| {
                    diag.push("Invalid write argument type `{s}`", .{@tagName(l.type(.at(1)))}) catch {};
                }
                return error.InvalidArgument;
            },
        }
    };
    file.file.seekFromEnd(0) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to seek file `{s}` from end because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
    file.file.writeAll(contents) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to write file `{s}` because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
}

fn readFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        readFile(l, &diagnostics),
        &diagnostics,
    );
}

fn readFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const file: *File = try .to(l, .at(1));
    const size = l.toIntegerx(.at(2)) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid read size `{s}`", .{cart.util.tostring(l, .at(2))}) catch {};
        }
        return error.InvalidArgument;
    };

    const buffer = l.newBuffer(@intCast(size));

    const read = try file.file.read(buffer.mutable);
    if (read != size) {
        if (diagnostics) |diag| {
            diag.push("Failed to read requested size {}, read only {}", .{ size, read }) catch {};
        }
        return error.Unexpected;
    }

    return .at(-1);
}

fn absPath(l: *luau.State) !i32 {
    const file: *File = try .to(l, .at(1));
    const path = file.path;
    l.pushLengthString(path);
    return 1;
}

fn relPath(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);

    const file: *File = try .to(l, .at(1));
    const path = file.path;

    const allocator = l.allocator();

    const realpath = try context.cwd.realpathAlloc(allocator, "");
    defer allocator.free(realpath);

    const rel = try std.fs.path.relative(allocator, realpath, path);
    defer allocator.free(rel);

    l.pushLengthString(rel);
    return 1;
}

fn tell(l: *luau.State) !i32 {
    const file: *File = try .to(l, .at(1));
    const pos = try file.file.getPos();
    l.pushNumber(@floatFromInt(pos));
    return 1;
}

fn seekHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        seek(l),
        &diagnostics,
    );
}

fn seek(l: *luau.State) Error!void {
    const file: *File = try .to(l, .at(1));
    const pos = l.toIntegerx(.at(2)) orelse return error.InvalidArgument;
    file.file.seekTo(@intCast(pos)) catch |err| return err;
}

fn seekEndHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        seekEnd(l),
        &diagnostics,
    );
}

fn seekEnd(l: *luau.State) Error!void {
    const file: *File = try .to(l, .at(1));
    const pos = l.toIntegerx(.at(2)) orelse return error.InvalidArgument;
    file.file.seekFromEnd(@intCast(pos)) catch |err| return err;
}

fn kind(l: *luau.State) !i32 {
    const file: *File = try .to(l, .at(1));
    const stat = try file.file.stat();
    l.pushLengthString(@tagName(File.Kind.fromStd(stat.kind)));
    return 1;
}

fn kindPath(l: *luau.State) Error!i32 {
    const context: *cart.Context = try .fromState(l);
    const path = l.toLengthString(.at(1));

    const stat = context.cwd.statFile(path) catch |err| blk: {
        if (err == error.FileNotFound) break :blk {
            l.pushNil();
            return 1;
        };
        return err;
    };
    l.pushVal(File.Kind.fromStd(stat.kind), 0);
    return 1;
}

fn lockHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        lockFn(l, &diagnostics),
        &diagnostics,
    );
}

fn lockFn(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const file: *File = try .to(l, .at(1));
    const lock_type = l.toLengthString(.at(2));
    const lock = std.meta.stringToEnum(std.fs.File.Lock, lock_type) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid lock type `{s}`", .{lock_type}) catch {};
        }
        return error.InvalidArgument;
    };
    fs.lock(file.file, lock) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to lock file `{s}` because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
}

fn tryLockHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!bool,
        tryLock(l, &diagnostics),
        &diagnostics,
    );
}

fn tryLock(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!bool {
    const file: *File = try .to(l, .at(1));
    const lock_type = l.toLengthString(.at(2));
    const lock = std.meta.stringToEnum(std.fs.File.Lock, lock_type) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid lock type `{s}`", .{lock_type}) catch {};
        }
        return error.InvalidArgument;
    };
    const locked = fs.tryLock(file.file, lock) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to lock file `{s}` because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
    return locked;
}

fn unlockHandled(l: *luau.State) i32 {
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        unlock(l),
        null,
    );
}

fn unlock(l: *luau.State) Error!void {
    const file: *File = try .to(l, .at(1));
    fs.unlock(file.file);
}

fn symLinkFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        symLinkGeneric(l, &diagnostics, false),
        &diagnostics,
    );
}

fn symLinkDirHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        symLinkGeneric(l, &diagnostics, true),
        &diagnostics,
    );
}

fn symLinkGeneric(l: *luau.State, diagnostics: ?*cart.util.Diagnostics, is_directory: bool) Error!void {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));
    const target = l.toLengthString(.at(2));

    context.cwd.symLink(path, target, .{ .is_directory = is_directory }) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create symlink `{s}` to `{s}` because {s}", .{ path, target, errorName(err) }) catch {};
        }
        return err;
    };
}

fn hardLinkFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        hardLinkGeneric(l, &diagnostics),
        &diagnostics,
    );
}

fn hardLinkDirHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        hardLinkGeneric(l, &diagnostics),
        &diagnostics,
    );
}

fn hardLinkGeneric(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const context: *cart.Context = try .fromState(l);

    const path = l.toLengthString(.at(1));
    const target = l.toLengthString(.at(2));

    fs.hardLinkZ(context.cwd, path, target) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create hardlink `{s}` to `{s}` because {s}", .{ path, target, errorName(err) }) catch {};
        }
        return err;
    };
}

fn isReadOnlyHandled(l: *luau.State) i32 {
    return cart.util.returnValue(l, bool, isReadOnly(l) catch false);
}

fn isReadOnly(l: *luau.State) !bool {
    const file: *File = try .to(l, .at(1));
    const meta = try file.file.metadata();
    return meta.permissions().readOnly();
}

fn setReadOnlyHandled(l: *luau.State) i32 {
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        setReadOnly(l),
        null,
    );
}

fn setReadOnly(l: *luau.State) Error!void {
    if (native_os == .wasi) {
        return error.NotImplemented;
    }
    const file: *File = try .to(l, .at(1));
    const read_only = l.toBoolean(.at(2));
    var permissions: std.fs.File.Permissions = std.mem.zeroes(std.fs.File.Permissions);
    permissions.setReadOnly(read_only);
    try file.file.setPermissions(permissions);
}

const fs = struct {
    const windows = std.os.windows;
    const posix = std.os.posix;
    const range_off: windows.LARGE_INTEGER = 0;
    const range_len: windows.LARGE_INTEGER = 1;

    // from https://github.com/ziglang/zig/pull/21306
    pub fn lock(file: std.fs.File, l: std.fs.File.Lock) std.fs.File.LockError!void {
        if (native_os == .windows) {
            var io_status_block: windows.IO_STATUS_BLOCK = undefined;
            const exclusive = switch (l) {
                .none => return windows.UnlockFile(
                    file.handle,
                    &io_status_block,
                    &range_off,
                    &range_len,
                    null,
                ) catch |err| switch (err) {
                    error.RangeNotLocked => unreachable, // Function assumes locked.
                    error.Unexpected => return error.Unexpected,
                },
                .shared => false,
                .exclusive => true,
            };
            return windows.LockFile(
                file.handle,
                null,
                null,
                null,
                &io_status_block,
                &range_off,
                &range_len,
                null,
                windows.FALSE, // non-blocking=false
                @intFromBool(exclusive),
            ) catch |err| switch (err) {
                error.WouldBlock => unreachable, // non-blocking=false
                else => |e| return e,
            };
        } else {
            return posix.flock(file.handle, switch (l) {
                .none => posix.LOCK.UN,
                .shared => posix.LOCK.SH,
                .exclusive => posix.LOCK.EX,
            }) catch |err| switch (err) {
                error.WouldBlock => unreachable, // non-blocking=false
                else => |e| return e,
            };
        }
    }

    /// Assumes the file is locked.
    pub fn unlock(file: std.fs.File) void {
        if (native_os == .windows) {
            var io_status_block: windows.IO_STATUS_BLOCK = undefined;
            return windows.UnlockFile(
                file.handle,
                &io_status_block,
                &range_off,
                &range_len,
                null,
            ) catch |err| switch (err) {
                error.RangeNotLocked => unreachable, // Function assumes unlocked.
                error.Unexpected => unreachable, // Resource deallocation must succeed.
            };
        } else {
            return posix.flock(file.handle, posix.LOCK.UN) catch |err| switch (err) {
                error.WouldBlock => unreachable, // unlocking can't block
                error.SystemResources => unreachable, // We are deallocating resources.
                error.FileLocksNotSupported => unreachable, // We already got the lock.
                error.Unexpected => unreachable, // Resource deallocation must succeed.
            };
        }
    }

    pub fn tryLock(file: std.fs.File, l: std.fs.File.Lock) std.fs.File.LockError!bool {
        if (native_os == .windows) {
            var io_status_block: windows.IO_STATUS_BLOCK = undefined;
            const exclusive = switch (l) {
                .none => {
                    windows.UnlockFile(
                        file.handle,
                        &io_status_block,
                        &range_off,
                        &range_len,
                        null,
                    ) catch |err| switch (err) {
                        error.RangeNotLocked => unreachable, // The file is assumed to be locked.
                        error.Unexpected => return error.Unexpected,
                    };

                    return true;
                },
                .shared => false,
                .exclusive => true,
            };
            windows.LockFile(
                file.handle,
                null,
                null,
                null,
                &io_status_block,
                &range_off,
                &range_len,
                null,
                windows.TRUE, // non-blocking=true
                @intFromBool(exclusive),
            ) catch |err| switch (err) {
                error.WouldBlock => return false,
                else => |e| return e,
            };
        } else {
            posix.flock(file.handle, switch (l) {
                .none => posix.LOCK.UN,
                .shared => posix.LOCK.SH | posix.LOCK.NB,
                .exclusive => posix.LOCK.EX | posix.LOCK.NB,
            }) catch |err| switch (err) {
                error.WouldBlock => return false,
                else => |e| return e,
            };
        }
        return true;
    }

    pub fn hardLinkZ(
        self: std.fs.Dir,
        target_path_c: [*:0]const u8,
        hard_link_path_c: [*:0]const u8,
    ) !void {
        if (native_os == .windows) {
            const target_path_w = try windows.cStrToPrefixedFileW(self.fd, target_path_c);
            const hard_link_path_w = try windows.cStrToPrefixedFileW(self.fd, hard_link_path_c);
            const result = CreateHardLinkW(
                hard_link_path_w.span(),
                target_path_w.span(),
                null,
            );
            if (result == windows.FALSE) {
                return error.Unexpected;
            }
        } else return posix.link(std.mem.span(target_path_c), std.mem.span(hard_link_path_c));
    }

    extern fn CreateHardLinkW(
        lpFileName: [*:0]const u16,
        lpExistingFileName: [*:0]const u16,
        lpSecurityAttributes: ?*windows.SECURITY_ATTRIBUTES,
    ) windows.BOOL;
};

fn parseOpenFlags(l: *luau.State, at: luau.vm.Index, diagnostics: ?*cart.util.Diagnostics) !File.OpenFlags {
    if (l.type(at) != .table) {
        if (diagnostics) |diag| {
            diag.push("Invalid open flags `{s}`, must be a table", .{cart.util.tostring(l, at)}) catch {};
        }
        return error.InvalidArgument;
    }

    const field_mode_type = l.getField(at.shiftIfNegative(-1), "mode");
    if (field_mode_type != .string and field_mode_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid mode `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const mode = std.meta.stringToEnum(File.OpenMode, l.toLengthString(.at(-1))) orelse blk: {
        if (field_mode_type == .nil) break :blk .readonly;
        if (diagnostics) |diag| {
            diag.push("Invalid mode `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    };
    l.pop(1);

    const field_lock_type = l.getField(at.shiftIfNegative(-1), "lock");
    if (field_lock_type != .string and field_lock_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid lock `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const lock = std.meta.stringToEnum(std.fs.File.Lock, l.toLengthString(.at(-1))) orelse blk: {
        if (field_lock_type == .nil) break :blk .none;
        if (diagnostics) |diag| {
            diag.push("Invalid lock `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    };
    l.pop(1);

    const field_create_type = l.getField(at.shiftIfNegative(-1), "create");
    if (field_create_type != .boolean and field_create_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid create `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const create = if (field_create_type == .nil) true else l.toBoolean(.at(-1));
    l.pop(1);

    return .{
        .mode = mode.toStd(),
        .lock = lock,
        .create = create,
    };
}

fn parseCreateFlags(l: *luau.State, at: luau.vm.Index, diagnostics: ?*cart.util.Diagnostics) !File.CreateFlags {
    if (l.type(at) != .table) {
        if (diagnostics) |diag| {
            diag.push("Invalid create flags `{s}`, must be a table", .{cart.util.tostring(l, at)}) catch {};
        }
        return error.InvalidArgument;
    }

    const field_mode_type = l.getField(at.shiftIfNegative(-1), "mode");
    if (field_mode_type != .string and field_mode_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid mode `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const mode = std.meta.stringToEnum(File.OpenMode, l.toLengthString(.at(-1))) orelse blk: {
        if (field_mode_type == .nil) break :blk .readonly;
        if (diagnostics) |diag| {
            diag.push("Invalid mode `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    };
    l.pop(1);

    const field_lock_type = l.getField(at.shiftIfNegative(-1), "lock");
    if (field_lock_type != .string and field_lock_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid lock `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const lock = std.meta.stringToEnum(std.fs.File.Lock, l.toLengthString(.at(-1))) orelse blk: {
        if (field_lock_type == .nil) break :blk .none;
        if (diagnostics) |diag| {
            diag.push("Invalid lock `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    };
    l.pop(1);

    const field_exclusive_type = l.getField(at.shiftIfNegative(-1), "exclusive");
    if (field_exclusive_type != .boolean and field_exclusive_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid exclusive `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const exclusive = if (field_exclusive_type == .nil) false else l.toBoolean(.at(-1));
    l.pop(1);

    const field_truncate_type = l.getField(at.shiftIfNegative(-1), "truncate");
    if (field_truncate_type != .boolean and field_truncate_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid truncate `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const truncate = if (field_truncate_type == .nil) true else l.toBoolean(.at(-1));
    l.pop(1);

    return .{
        .mode = mode.toStd(),
        .lock = lock,
        .exclusive = exclusive,
        .truncate = truncate,
    };
}

fn fileToString(l: *luau.State) Error!i32 {
    const file: *File = try .to(l, .at(1));
    const path = file.path;
    try l.pushFmtString("cart/file({s})", .{path});
    return 1;
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const native_os = builtin.os.tag;
