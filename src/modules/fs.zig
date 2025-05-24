pub fn push(context: *cart.Context) !void {
    const l = context.state;

    // File
    try l.newMetatable(file_metatable);
    l.pushTable(.at(-1), .{
        .__type = file_metatable,
        .__metatable = "This metatable is locked",
        .__tostring = fileToString,
        // .__index = luau.vm.Index.at(-2),
        .__index = .{
            .close = closeFileHandled,
            .write = luau.vm.ClosureK.withContinuation(writeFileHandled, writeFileCont, "write"),
            .pwrite = luau.vm.ClosureK.withContinuation(pwriteFileHandled, writeFileCont, "pwrite"),
            .read = luau.vm.ClosureK.withContinuation(readFileHandled, readFileCont, "read"),
            .pread = luau.vm.ClosureK.withContinuation(preadFileHandled, readFileCont, "pread"),
            // .write = writeFileHandled,
            // .append = appendFileHandled,
            // .read = readFileHandled,
            .readtoend = readToEndHandled,
            .abspath = absPath,
            .relpath = relPath,
            .tell = tell,
            .seek = seekHandled,
            .lock = lockHandled,
            .trylock = tryLockHandled,
            .unlock = unlockHandled,
            .kind = kind,
            .isreadonly = isReadOnlyHandled,
            .setreadonly = setReadOnlyHandled,
        },
    }, null);
    l.setReadonly(.at(-1), true);
    l.pop(1);

    l.createPushTable(.{
        .openfile = openFileHandled,
        .createfile = createFileHandled,
        .makepath = makePathHandled,
        .delete = deleteHandled,
        .kindpath = kindPath,
        .symlinkfile = symLinkFileHandled,
        .symlinkdir = symLinkDirHandled,
        .hardlinkfile = hardLinkFileHandled,
        .hardlinkdir = hardLinkDirHandled,

        .stdin = getStdin,
        .stdout = getStdout,
        .stderr = getStderr,
    }, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/fs");
    try push(context);
    luau.require.registermodule(context.state);
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
    EOF,
    OutOfMemory,
    Unexpected,
};

pub const YieldError = Error || error{YieldLuau1};

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
        error.EOF => return "EOF",
    };
}

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
        follow_symlinks: bool = true,
    };

    pub const Path = union(enum) {
        const_relative: []const u8,
        relative: [:0]u8,
        stdin,
        stdout,
        stderr,

        pub fn rel(path: []const u8) Path {
            return .{ .const_relative = path };
        }

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try switch (self) {
                .relative => |r| writer.writeAll(r),
                .stdin => writer.writeAll("stdin"),
                .stdout => writer.writeAll("stdout"),
                .stderr => writer.writeAll("stderr"),
                .const_relative => |r| writer.writeAll(r),
            };
        }
    };

    context: *cart.Context,
    completion: xev.Completion = undefined,

    ref: union(enum) { valid: luau.vm.Ref, dtor: luau.vm.Ref, dead },

    allocator: std.mem.Allocator,
    file: xev.File,
    /// storing path because zig fs discourages using realpath
    path: Path,

    current_lock: std.fs.File.Lock = .none,

    pub inline fn stdFile(self: File) std.fs.File {
        return .{ .handle = self.file.fd };
    }

    pub fn push(l: *luau.State, context: *cart.Context, file: std.fs.File, path: Path) !*File {
        const allocator = l.allocator();
        const new_file: *File = @alignCast(@ptrCast(l.newUserdataDtor(
            @sizeOf(File),
            @ptrCast(&fileDtor),
        ) orelse
            return error.OutOfMemory));
        const ref = l.ref(.at(-1));
        errdefer l.unref(ref);
        _ = l.getMetatableRegistry(file_metatable);
        l.setMetatable(.at(-2));
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        new_file.* = .{
            .context = context,
            .ref = .{ .valid = ref },
            .file = try .init(file),
            .allocator = allocator,
            .path = path: {
                switch (path) {
                    .const_relative => |rel| {
                        break :path .{ .relative = try allocator.dupeZ(
                            u8,
                            try std.fs.realpath(rel, buf[0..]),
                        ) };
                    },
                    .relative => @panic("relative path not supported as push input"),
                    else => |other| break :path other,
                }
            },
        };
        return new_file;
    }

    pub fn to(l: *luau.State, at: luau.vm.Index) !*File {
        const file: *File = @alignCast(@ptrCast(l.checkUserdata(at, file_metatable) orelse return error.NotAFile));
        if (file.ref != .valid) return error.InvalidFile;
        return file;
    }
};

fn fileDtor(file: *File) callconv(.c) void {
    if (file.ref == .valid) {
        file.ref = .{ .dtor = file.ref.valid };
        switch (file.path) {
            .relative => |rel| file.allocator.free(rel),
            else => {},
        }
        if (file.context.exiting) {
            // close synchronously
            file.stdFile().close();
            return;
        }
        file.file.close(&file.context.loop, &file.completion, File, file, (struct {
            fn callback(
                ud: ?*File,
                _: *xev.Loop,
                _: *xev.Completion,
                _: xev.File,
                _: xev.CloseError!void,
            ) xev.CallbackAction {
                ud.?.context.state.unref(ud.?.ref.dtor);
                ud.?.ref = .dead;
                return .disarm;
            }
        }).callback);
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

    const opened = fs.openFile(
        context.cwd,
        path,
        std_flags,
        flags.follow_symlinks,
    ) catch |err| blk: {
        if (err == error.FileNotFound and flags.create) {
            const create_flags: std.fs.File.CreateFlags = .{
                .lock = flags.lock,
                .exclusive = false,
                .read = true,
            };
            const created = fs.createFile(context.cwd, path, create_flags) catch |create_err| {
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

    const file = try File.push(l, context, opened, .rel(path));
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

    const created = fs.createFile(context.cwd, path, std_flags) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create file `{s}` because {s}", .{ path, errorName(err) }) catch {};
        }
        return err;
    };

    const file = try File.push(l, context, created, .rel(path));
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

const WriteFileAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,
    /// a bittt hacky but its just that iocp doesnt actually set the file pointer with write
    set_file_pointer: ?usize = null,

    diagnostics: cart.util.Diagnostics = .{},

    result: xev.WriteError!usize = undefined,
    buffer_ref: luau.vm.Ref = .no,

    pub fn callback(
        opt_self: ?*WriteFileAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        f: xev.File,
        _: xev.WriteBuffer,
        r: xev.WriteError!usize,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.result = r;
        const file: std.fs.File = .{ .handle = f.fd };
        if (self.set_file_pointer) |set_pos| {
            _ = file.seekTo(set_pos) catch @panic("Failed to set file pointer");
        }
        _ = r catch |err| {
            self.diagnostics.push("Failed to write file because {s}", .{errorName(err)}) catch {};
        };
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn writeFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!void,
        writeFile(l, &diagnostics),
        &diagnostics,
    );
}

fn writeFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!void {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

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
    var max_bytes = contents.len;
    if (l.toIntegerx(.at(3))) |param_max_bytes| if (param_max_bytes < max_bytes) {
        max_bytes = @intCast(param_max_bytes);
    };

    const current_position = file.stdFile().getPos() catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to get file position because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
    const new_position = current_position + max_bytes;

    const future = allocator.create(WriteFileAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
        .set_file_pointer = new_position,
    };
    future.diagnostics.init();

    file.file.write(
        &context.loop,
        &future.completion,
        .{ .slice = contents[0..max_bytes] },
        WriteFileAsync,
        future,
        &WriteFileAsync.callback,
    );

    return error.YieldLuau1;
}

fn pwriteFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!void,
        pwriteFile(l, &diagnostics),
        &diagnostics,
    );
}

fn pwriteFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!void {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

    const file: *File = try .to(l, .at(1));
    const offset = l.toIntegerx(.at(2)) orelse return error.InvalidArgument;
    const contents: []const u8 = blk: {
        switch (l.type(.at(3))) {
            .string => break :blk l.toLengthString(.at(3)),
            .buffer => break :blk l.toBuffer(.at(3)).constSlice(),
            else => {
                if (diagnostics) |diag| {
                    diag.push("Invalid write argument type `{s}`", .{@tagName(l.type(.at(1)))}) catch {};
                }
                return error.InvalidArgument;
            },
        }
    };
    var max_bytes = contents.len;
    if (l.toIntegerx(.at(4))) |param_max_bytes| if (param_max_bytes < max_bytes) {
        max_bytes = @intCast(param_max_bytes);
    };

    const future = allocator.create(WriteFileAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
    };
    future.diagnostics.init();

    file.file.pwrite(
        &context.loop,
        &future.completion,
        .{ .slice = contents[0..max_bytes] },
        @intCast(offset),
        WriteFileAsync,
        future,
        &WriteFileAsync.callback,
    );

    return error.YieldLuau1;
}

fn writeFileCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *WriteFileAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    _ = status;
    if (future.result) |_| {
        cart.util.pushOk(l, void, {}, 0);
    } else |bad| {
        cart.util.pushError(l, @errorName(bad), &future.diagnostics, null);
    }
    return 1;
}

const ReadFileAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    diagnostics: cart.util.Diagnostics = .{},

    result: xev.ReadError!usize = undefined,
    buffer_ref: luau.vm.Ref = .no,

    pub fn callback(
        opt_self: ?*ReadFileAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.File,
        _: xev.ReadBuffer,
        r: xev.ReadError!usize,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.result = r;
        _ = r catch |err| {
            self.diagnostics.push("Failed to read file because {s}", .{errorName(err)}) catch {};
        };
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn readFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!usize,
        readFile(l, &diagnostics),
        &diagnostics,
    );
}

fn readFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!usize {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

    const file: *File = try .to(l, .at(1));
    const buffer: luau.vm.Buffer = if (l.type(.at(2)) != .buffer) {
        if (diagnostics) |diag| {
            diag.push("Invalid read argument type `{s}`", .{@tagName(l.type(.at(2)))}) catch {};
        }
        return error.InvalidArgument;
    } else l.toBuffer(.at(2));

    const future = allocator.create(ReadFileAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
    };
    future.diagnostics.init();

    file.file.read(
        &context.loop,
        &future.completion,
        .{ .slice = buffer.mutable },
        ReadFileAsync,
        future,
        &ReadFileAsync.callback,
    );

    return error.YieldLuau1;
}

fn preadFileHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!usize,
        preadFile(l, &diagnostics),
        &diagnostics,
    );
}

fn preadFile(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!usize {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

    const file: *File = try .to(l, .at(1));
    const offset = l.toIntegerx(.at(2)) orelse return error.InvalidArgument;
    const buffer: luau.vm.Buffer = if (l.type(.at(3)) != .buffer) {
        if (diagnostics) |diag| {
            diag.push("Invalid read argument type `{s}`", .{@tagName(l.type(.at(3)))}) catch {};
        }
        return error.InvalidArgument;
    } else l.toBuffer(.at(3));

    const future = allocator.create(ReadFileAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
    };
    future.diagnostics.init();

    file.file.pread(
        &context.loop,
        &future.completion,
        .{ .slice = buffer.mutable },
        @intCast(offset),
        ReadFileAsync,
        future,
        &ReadFileAsync.callback,
    );

    return error.YieldLuau1;
}

fn readFileCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *ReadFileAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    _ = status;
    cart.util.pushErrorUnion(l, xev.ReadError!usize, future.result, &future.diagnostics);
    return 1;
}

fn readToEndHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        readFileToEnd(l, &diagnostics),
        &diagnostics,
    );
}

fn readFileToEnd(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const file: *File = try .to(l, .at(1));
    const allocator = l.allocator();

    const read = file.stdFile().readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to read file `{s}` because {s}", .{ file.path, errorName(err) }) catch {};
        }
        return err;
    };
    defer allocator.free(read);

    const buffer = l.newBuffer(read.len);
    @memcpy(buffer.mutable, read);
    return .at(-1);
}

fn absPath(l: *luau.State) !i32 {
    const file: *File = try .to(l, .at(1));
    const path = switch (file.path) {
        .relative => |rel| rel,
        else => |other| {
            l.pushLengthString(@tagName(other));
            return 1;
        },
    };
    l.pushLengthString(path);
    return 1;
}

fn relPath(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);

    const file: *File = try .to(l, .at(1));
    const path = switch (file.path) {
        .relative => |rel| rel,
        else => |other| {
            l.pushLengthString(@tagName(other));
            return 1;
        },
    };

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
    const pos = try file.stdFile().getPos();
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
    if (pos >= 0) {
        try file.stdFile().seekTo(@intCast(pos));
    } else {
        try file.stdFile().seekFromEnd(@intCast(-pos - 1));
    }
}

fn kind(l: *luau.State) !i32 {
    const file: *File = try .to(l, .at(1));
    const stat = try file.stdFile().stat();
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
    fs.lock(file.stdFile(), lock) catch |err| {
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
    const locked = fs.tryLock(file.stdFile(), lock) catch |err| {
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
    fs.unlock(file.stdFile());
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
    const meta = try file.stdFile().metadata();
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
    try file.stdFile().setPermissions(permissions);
}

fn getStdin(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);
    const file = std.io.getStdIn();
    _ = try File.push(l, context, file, .stdin);
    return 1;
}

fn getStdout(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);
    const file = std.io.getStdOut();
    _ = try File.push(l, context, file, .stdout);
    return 1;
}

fn getStderr(l: *luau.State) !i32 {
    const context: *cart.Context = try .fromState(l);
    const file = std.io.getStdErr();
    _ = try File.push(l, context, file, .stderr);
    return 1;
}

const fs = struct {
    const windows = std.os.windows;
    const posix = std.posix;
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

    /// need this so that we open overlapped files on Windows
    pub fn openFile(self: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.OpenFlags, follow_symlinks: bool) std.fs.File.OpenError!std.fs.File {
        if (comptime native_os == .windows) {
            const path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
            const sub_path_w = path_w.span();
            const file: std.fs.File = .{
                .handle = try windows_ext.OpenFile(sub_path_w, .{
                    .dir = self.fd,
                    .access_mask = std.os.windows.SYNCHRONIZE |
                        (if (flags.isRead()) @as(u32, std.os.windows.GENERIC_READ) else 0) |
                        (if (flags.isWrite()) @as(u32, std.os.windows.GENERIC_WRITE) else 0),
                    .creation = std.os.windows.FILE_OPEN,
                    .follow_symlinks = follow_symlinks,
                }),
            };
            errdefer file.close();
            var io: std.os.windows.IO_STATUS_BLOCK = undefined;
            const exclusive = switch (flags.lock) {
                .none => return file,
                .shared => false,
                .exclusive => true,
            };
            try std.os.windows.LockFile(
                file.handle,
                null,
                null,
                null,
                &io,
                &range_off,
                &range_len,
                null,
                @intFromBool(flags.lock_nonblocking),
                @intFromBool(exclusive),
            );
            return file;
        }
        return self.openFile(sub_path, flags);
    }

    /// similar to above openFile, but creating files
    pub fn createFile(self: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) std.fs.File.OpenError!std.fs.File {
        if (comptime native_os == .windows) {
            const path_w = try windows.sliceToPrefixedFileW(self.fd, sub_path);
            const sub_path_w = path_w.span();
            const read_flag = if (flags.read) @as(u32, std.os.windows.GENERIC_READ) else 0;
            const file: std.fs.File = .{
                .handle = try windows_ext.OpenFile(sub_path_w, .{
                    .dir = self.fd,
                    .access_mask = std.os.windows.SYNCHRONIZE | std.os.windows.GENERIC_WRITE | read_flag,
                    .creation = if (flags.exclusive)
                        @as(u32, std.os.windows.FILE_CREATE)
                    else if (flags.truncate)
                        @as(u32, std.os.windows.FILE_OVERWRITE_IF)
                    else
                        @as(u32, std.os.windows.FILE_OPEN_IF),
                    .follow_symlinks = false,
                }),
            };
            errdefer file.close();
            var io: std.os.windows.IO_STATUS_BLOCK = undefined;
            const exclusive = switch (flags.lock) {
                .none => return file,
                .shared => false,
                .exclusive => true,
            };
            try std.os.windows.LockFile(
                file.handle,
                null,
                null,
                null,
                &io,
                &range_off,
                &range_len,
                null,
                @intFromBool(flags.lock_nonblocking),
                @intFromBool(exclusive),
            );
            return file;
        }
        return self.createFile(sub_path, flags);
    }
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

    const field_follow_symlinks_type = l.getField(at.shiftIfNegative(-1), "follow_symlinks");
    if (field_follow_symlinks_type != .boolean and field_follow_symlinks_type != .nil) {
        if (diagnostics) |diag| {
            diag.push("Invalid follow_symlinks `{s}`", .{cart.util.tostring(l, .at(-1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const follow_symlinks = if (field_follow_symlinks_type == .nil) true else l.toBoolean(.at(-1));
    l.pop(1);

    return .{
        .mode = mode.toStd(),
        .lock = lock,
        .create = create,
        .follow_symlinks = follow_symlinks,
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

const windows_ext = struct {
    /// modified to not block with symlink resolution and thus to allow for async file opening
    pub fn OpenFile(sub_path_w: []const u16, options: std.os.windows.OpenFileOptions) std.os.windows.OpenError!std.os.windows.HANDLE {
        if (std.mem.eql(u16, sub_path_w, &[_]u16{'.'}) and options.filter == .file_only) {
            return error.IsDir;
        }
        if (std.mem.eql(u16, sub_path_w, &[_]u16{ '.', '.' }) and options.filter == .file_only) {
            return error.IsDir;
        }

        var result: std.os.windows.HANDLE = undefined;

        const path_len_bytes = std.math.cast(u16, sub_path_w.len * 2) orelse return error.NameTooLong;
        var nt_name = std.os.windows.UNICODE_STRING{
            .Length = path_len_bytes,
            .MaximumLength = path_len_bytes,
            .Buffer = @constCast(sub_path_w.ptr),
        };
        var attr = std.os.windows.OBJECT_ATTRIBUTES{
            .Length = @sizeOf(std.os.windows.OBJECT_ATTRIBUTES),
            .RootDirectory = if (std.fs.path.isAbsoluteWindowsWTF16(sub_path_w)) null else options.dir,
            .Attributes = if (options.sa) |ptr| blk: { // Note we do not use OBJ_CASE_INSENSITIVE here.
                const inherit: std.os.windows.ULONG = if (ptr.bInheritHandle == std.os.windows.TRUE) std.os.windows.OBJ_INHERIT else 0;
                break :blk inherit;
            } else 0,
            .ObjectName = &nt_name,
            .SecurityDescriptor = if (options.sa) |ptr| ptr.lpSecurityDescriptor else null,
            .SecurityQualityOfService = null,
        };
        var io: std.os.windows.IO_STATUS_BLOCK = undefined;
        const blocking_flag: std.os.windows.ULONG = 0; //std.os.windows.FILE_SYNCHRONOUS_IO_NONALERT;
        const file_or_dir_flag: std.os.windows.ULONG = switch (options.filter) {
            .file_only => std.os.windows.FILE_NON_DIRECTORY_FILE,
            .dir_only => std.os.windows.FILE_DIRECTORY_FILE,
            .any => 0,
        };
        // If we're not following symlinks, we need to ensure we don't pass in any synchronization flags such as FILE_SYNCHRONOUS_IO_NONALERT.
        const flags: std.os.windows.ULONG = if (options.follow_symlinks)
            file_or_dir_flag | blocking_flag
        else
            file_or_dir_flag | std.os.windows.FILE_OPEN_REPARSE_POINT;

        while (true) {
            const rc = std.os.windows.ntdll.NtCreateFile(
                &result,
                options.access_mask,
                &attr,
                &io,
                null,
                std.os.windows.FILE_ATTRIBUTE_NORMAL,
                options.share_access,
                options.creation,
                flags,
                null,
                0,
            );
            switch (rc) {
                .SUCCESS => return result,
                .OBJECT_NAME_INVALID => return error.BadPathName,
                .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
                .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
                .BAD_NETWORK_PATH => return error.NetworkNotFound, // \\server was not found
                .BAD_NETWORK_NAME => return error.NetworkNotFound, // \\server was found but \\server\share wasn't
                .NO_MEDIA_IN_DEVICE => return error.NoDevice,
                .INVALID_PARAMETER => unreachable,
                .SHARING_VIOLATION => return error.AccessDenied,
                .ACCESS_DENIED => return error.AccessDenied,
                .PIPE_BUSY => return error.PipeBusy,
                .PIPE_NOT_AVAILABLE => return error.NoDevice,
                .OBJECT_PATH_SYNTAX_BAD => unreachable,
                .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
                .FILE_IS_A_DIRECTORY => return error.IsDir,
                .NOT_A_DIRECTORY => return error.NotDir,
                .USER_MAPPED_FILE => return error.AccessDenied,
                .INVALID_HANDLE => unreachable,
                .DELETE_PENDING => {
                    // This error means that there *was* a file in this location on
                    // the file system, but it was deleted. However, the OS is not
                    // finished with the deletion operation, and so this CreateFile
                    // call has failed. There is not really a sane way to handle
                    // this other than retrying the creation after the OS finishes
                    // the deletion.
                    std.time.sleep(std.time.ns_per_ms);
                    continue;
                },
                .VIRUS_INFECTED, .VIRUS_DELETED => return error.AntivirusInterference,
                else => return std.os.windows.unexpectedStatus(rc),
            }
        }
    }
};

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const xev = @import("xev");
const luau = cart.luau;

const native_os = builtin.os.tag;
