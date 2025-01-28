const READER_METATABLE = "cart_io_reader";
const WRITER_METATABLE = "cart_io_writer";

const Erased = struct {
    pub const alignment = @sizeOf(usize);
    allocator: std.mem.Allocator,
    context: *align(alignment) anyopaque,
    len: usize,

    pub fn init(allocator: std.mem.Allocator, comptime T: type) !Erased {
        const len = @sizeOf(T);
        const context = try allocator.create(T);
        return .{ .allocator = allocator, .context = @ptrCast(context), .len = len };
    }

    pub fn deinit(self: *Erased) void {
        self.allocator.free(@as([*]align(alignment) const u8, @ptrCast(self.context))[0..self.len]);
    }

    pub fn as(self: *Erased, comptime T: type) *T {
        return @alignCast(@ptrCast(self.context));
    }
};

pub const LReader = struct {
    reader: std.io.AnyReader,
    erased: Erased,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(READER_METATABLE) catch @panic("failed to create reader metatable");
        l.pushString(READER_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lRead, "read");
        l.setField(-2, "read");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("cart.Reader");
        return 1;
    }

    pub fn push(l: *luau.Luau, comptime R: type) !*LReader {
        var self = l.newUserdataDtor(LReader, dtor);
        _ = l.getMetatableRegistry(READER_METATABLE);
        l.setMetatable(-2);
        self.erased = try .init(l.allocator(), R);
        return self;
    }

    fn dtor(self: *LReader) void {
        self.erased.deinit();
    }

    // 1: reader
    // 2: buffer
    // returns: number (bytes read)
    fn lRead(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LReader, 1) catch l.argError(1, "expected reader");
        const buffer = l.toBuffer(2) catch l.argError(2, "expected buffer");
        const bytes_read = try self.reader.read(buffer);
        l.pushNumber(@floatFromInt(bytes_read));
        return 1;
    }
};

pub const LWriter = struct {
    writer: std.io.AnyWriter,
    erased: Erased,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(WRITER_METATABLE) catch @panic("failed to create writer metatable");
        l.pushString(WRITER_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lWrite, "write");
        l.setField(-2, "write");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("cart.Writer");
        return 1;
    }

    pub fn push(l: *luau.Luau, comptime W: type) !*LWriter {
        var self = l.newUserdataDtor(LWriter, dtor);
        _ = l.getMetatableRegistry(WRITER_METATABLE);
        l.setMetatable(-2);
        self.erased = try .init(l.allocator(), W);
        return self;
    }

    fn dtor(self: *LWriter) void {
        self.erased.deinit();
    }

    // 1: reader
    // 2: buffer
    // returns: number (bytes written)
    fn lWrite(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LWriter, 1) catch l.argError(1, "expected writer");
        const buffer = l.toBuffer(2) catch l.argError(2, "expected buffer");
        const bytes_written = try self.writer.write(buffer);
        l.pushNumber(@floatFromInt(bytes_written));
        return 1;
    }
};

pub fn open(l: *luau.Luau) void {
    LReader.open(l);
    LWriter.open(l);

    l.newTable();

    l.pushString("readerFromBuffer");
    l.pushFunction(lReaderFromBuffer, "cart_readerFromBuffer");
    l.setTable(-3);

    l.pushString("writerFromBuffer");
    l.pushFunction(lWriterFromBuffer, "cart_writerFromBuffer");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

fn lReaderFromBuffer(l: *luau.Luau) !i32 {
    const buffer = l.toBuffer(1) catch l.argError(1, "expected buffer");
    const reader = try LReader.push(l, std.io.FixedBufferStream([]const u8));
    const rctx = reader.erased.as(std.io.FixedBufferStream([]const u8));
    rctx.* = .{ .buffer = buffer, .pos = 0 };
    reader.reader = rctx.reader().any();
    return 1;
}

fn lWriterFromBuffer(l: *luau.Luau) !i32 {
    const buffer = l.toBuffer(1) catch l.argError(1, "expected buffer");
    const writer = try LWriter.push(l, std.io.FixedBufferStream([]u8));
    const wctx = writer.erased.as(std.io.FixedBufferStream([]u8));
    wctx.* = .{ .buffer = buffer, .pos = 0 };
    writer.writer = wctx.writer().any();
    return 1;
}

const std = @import("std");
const luau = @import("luau");

const util = @import("../util.zig");

const Context = @import("../Context.zig");
const Platform = @import("../Platform.zig");
