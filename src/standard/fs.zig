const FILE_METATABLE = "cart_fs_file";

pub const LFile = struct {
    platform: Platform,
    file: ?Platform.File,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(FILE_METATABLE) catch @panic("failed to create file metatable");
        l.pushString(FILE_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lClose, "close");
        l.setField(-2, "close");
        l.pushFunction(lReader, "reader");
        l.setField(-2, "reader");
        l.pushFunction(lWriter, "writer");
        l.setField(-2, "writer");
        l.pushFunction(lGetReadonly, "getReadonly");
        l.setField(-2, "getReadonly");
        l.pushFunction(lSetReadonly, "setReadonly");
        l.setField(-2, "setReadonly");
        l.pushFunction(lGetPermissions, "getPermissions");
        l.setField(-2, "getPermissions");
        l.pushFunction(lSetPermissions, "setPermissions");
        l.setField(-2, "setPermissions");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("cart.File");
        return 1;
    }

    fn lClose(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        if (self.file) |f| {
            self.platform.closeFile(f);
            self.file = null;
        } else {
            l.raiseErrorFmt("file already closed", .{}) catch unreachable;
        }
        return 0;
    }

    fn lGetReadonly(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        l.pushBoolean(file.getReadonly(self.platform));
        return 1;
    }

    fn lSetReadonly(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        const readonly = l.optBoolean(2) orelse l.argError(2, "expected boolean");
        try file.setReadonly(self.platform, readonly);
        return 0;
    }

    fn lGetPermissions(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        const class = util.parseStringAsEnum(Platform.Class, l, 2) orelse (l.argError(2, "expected class") catch unreachable);
        const permissions = file.getPermissions(class, self.platform);
        pushPermissions(l, permissions);
        return 1;
    }

    fn lSetPermissions(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        const class = util.parseStringAsEnum(Platform.Class, l, 2) orelse (l.argError(2, "expected class") catch unreachable);
        const permissions = parsePermissions(l, 3) orelse (l.argError(3, "expected permissions") catch unreachable);
        try file.setPermissions(self.platform, class, permissions);
        return 0;
    }

    fn lReader(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        const reader = try file.reader(self.platform);
        const r = try io.LReader.push(l, std.fs.File.Reader);
        const rctx: *std.fs.File.Reader = @alignCast(@ptrCast(r.context));
        rctx.* = reader;
        r.reader = rctx.any();

        return 1;
    }

    fn lWriter(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LFile, 1) catch l.argError(1, "expected file");
        const file = self.file orelse (l.raiseErrorFmt("file already closed", .{}) catch unreachable);
        const writer = try file.writer(self.platform);
        const w = try io.LWriter.push(l, std.fs.File.Writer);
        const wctx: *std.fs.File.Writer = @alignCast(@ptrCast(w.context));
        wctx.* = writer;
        w.writer = wctx.any();
        return 1;
    }

    pub fn push(l: *luau.Luau, platform: Platform, file: Platform.File) void {
        var self = l.newUserdataDtor(LFile, dtor);
        _ = l.getMetatableRegistry(FILE_METATABLE);
        l.setMetatable(-2);
        self.platform = platform;
        self.file = file;
    }

    fn dtor(self: *LFile) void {
        if (self.file) |f| {
            self.platform.closeFile(f);
            self.file = null;
        }
    }
};

pub fn open(l: *luau.Luau) void {
    LFile.open(l);

    l.newTable();

    l.pushString("openFile");
    l.pushFunction(lOpenFile, "cart_fs_openFile");
    l.setTable(-3);

    l.pushString("exists");
    l.pushFunction(lExists, "cart_fs_exists");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

pub fn parseFileFlags(l: *luau.Luau, index: i32) ?Platform.File.Flags {
    // get table
    if (l.typeOf(index) != .table) return null;
    _ = l.getField(index, "open_mode");
    const open_mode = util.parseStringAsEnum(std.fs.File.OpenMode, l, -1) orelse .read_only;
    l.pop(1);

    _ = l.getField(index, "lock");
    const lock = util.parseStringAsEnum(std.fs.File.Lock, l, -1) orelse .none;
    l.pop(1);

    _ = l.getField(index, "create_if_not_exists");
    const create_if_not_exists = l.optBoolean(-1) orelse true;

    _ = l.getField(index, "truncate_if_exists");
    const truncate_if_exists = l.optBoolean(-1) orelse false;

    return .{
        .mode = open_mode,
        .lock = lock,
        .create_if_not_exists = create_if_not_exists,
        .truncate_if_exists = truncate_if_exists,
    };
}

pub fn pushFileFlags(l: *luau.Luau, flags: Platform.File.Flags) void {
    l.newTable();

    l.pushString("open_mode");
    l.pushString(@tagName(flags.mode));
    l.setTable(-3);

    l.pushString("lock");
    l.pushString(@tagName(flags.lock));
    l.setTable(-3);

    l.pushString("create_if_not_exists");
    l.pushBoolean(flags.create_if_not_exists);
    l.setTable(-3);

    l.pushString("truncate_if_exists");
    l.pushBoolean(flags.truncate_if_exists);
    l.setTable(-3);
}

// table with keys:
// - read: boolean
// - write: boolean
// - execute: boolean
pub fn parsePermissions(l: *luau.Luau, index: i32) ?Platform.Permissions {
    if (l.typeOf(index) != .table) return null;
    _ = l.getField(index, "read");
    const read = l.optBoolean(-1);
    l.pop(1);

    _ = l.getField(index, "write");
    const write = l.optBoolean(-1);
    l.pop(1);

    _ = l.getField(index, "execute");
    const execute = l.optBoolean(-1);
    l.pop(1);

    return .{
        .read = read,
        .write = write,
        .execute = execute,
    };
}

pub fn pushPermissions(l: *luau.Luau, permissions: Platform.Permissions) void {
    l.newTable();

    l.pushString("read");
    if (permissions.read) |r|
        l.pushBoolean(r)
    else
        l.pushNil();
    l.setTable(-3);

    l.pushString("write");
    if (permissions.write) |w|
        l.pushBoolean(w)
    else
        l.pushNil();
    l.setTable(-3);

    l.pushString("execute");
    if (permissions.execute) |e|
        l.pushBoolean(e)
    else
        l.pushNil();
    l.setTable(-3);
}

// 1: string path
// 2: FileFlags flags
fn lOpenFile(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const path = l.toString(1) catch l.argError(1, "expected path as string");
    const flags = parseFileFlags(l, 2) orelse l.argError(2, "expected file flags");
    const file = try context.platform.openFile(path, flags);
    LFile.push(l, context.platform, file);
    return 1;
}

// 1: string path
fn lExists(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const path = l.toString(1) catch l.argError(1, "expected path as string");
    l.pushBoolean(context.platform.fileExists(path));
    return 1;
}

const std = @import("std");
const luau = @import("luau");

const util = @import("../util.zig");

const Context = @import("../Context.zig");
const Platform = @import("../Platform.zig");

const io = @import("io.zig");
