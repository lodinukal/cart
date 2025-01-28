const READER_METATABLE = "cart_io_reader";
const WRITER_METATABLE = "cart_io_writer";

const Erased = struct {
    pub const alignment = @sizeOf(usize);
    allocator: std.mem.Allocator,
    context: [*]align(alignment) u8,
    len: usize,
    free_fn: ?*const fn ([*]align(alignment) u8) void = null,

    pub fn init(allocator: std.mem.Allocator, comptime T: type) !Erased {
        const len = @sizeOf(T);
        const context = try allocator.create(T);
        const self: Erased = .{ .allocator = allocator, .context = @ptrCast(context), .len = len };
        @memset(self.context[0..len], 0);
        return self;
    }

    pub fn deinit(self: *Erased) void {
        if (self.free_fn) |f| f(self.context);
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

        l.pushFunction(lSkip, "skip");
        l.setField(-2, "skip");
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
        if (@hasDecl(R, "deinit")) {
            self.erased.free_fn = @ptrCast(&R.deinit);
        }
        return self;
    }

    pub fn pushReader(l: *luau.Luau, reader: anytype) !*LReader {
        const T = @TypeOf(reader);
        const self = try push(l, T);
        const rctx = self.erased.as(T);
        rctx.* = reader;
        self.reader = rctx.any();
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

    // 1: reader
    // 2: number bytes
    fn lSkip(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LReader, 1) catch l.argError(1, "expected reader");
        const bytes: usize = @intFromFloat(l.toNumber(2) catch l.argError(2, "expected number"));
        try self.reader.skipBytes(bytes, .{});
        return 0;
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
        if (@hasDecl(W, "deinit")) {
            self.erased.free_fn = @ptrCast(&W.deinit);
        }
        return self;
    }

    pub fn pushWriter(l: *luau.Luau, writer: anytype) !*LWriter {
        const T = @TypeOf(writer);
        const self = try push(l, T);
        const wctx = self.erased.as(T);
        wctx.* = writer;
        self.writer = wctx.any();
        return self;
    }

    fn dtor(self: *LWriter) void {
        self.erased.deinit();
    }

    // 1: reader
    // 2: buffer
    // 4: offset?
    // 3: max_bytes?
    // returns: number (bytes written)
    fn lWrite(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LWriter, 1) catch l.argError(1, "expected writer");
        const buffer = l.toBuffer(2) catch l.argError(2, "expected buffer");
        const offset: usize = @intFromFloat(l.optNumber(3) orelse 0);
        const max_bytes: usize = @intFromFloat(l.optNumber(4) orelse @as(f64, @floatFromInt(buffer.len - offset)));
        const bytes_written = try self.writer.write(buffer[offset..][0..max_bytes]);
        l.pushNumber(@floatFromInt(bytes_written));
        return 1;
    }
};

pub fn open(l: *luau.Luau) void {
    LReader.open(l);
    LWriter.open(l);

    l.newTable();

    l.pushString("reader_from_buffer");
    l.pushFunction(lReaderFromBuffer, "cart_reader_from_buffer");
    l.setTable(-3);

    l.pushString("writer_from_buffer");
    l.pushFunction(lWriterFromBuffer, "cart_writer_from_buffer");
    l.setTable(-3);

    l.pushString("pipe");
    l.pushFunction(lPipe, "cart_pipe");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

// the below reader/write buffer refs need the context to know when to unref the buffer
// as when it is being exited, references are cleaned up

/// constructed from a luau buffer
const ReaderBufferRef = struct {
    context: *const Context,
    l: *luau.Luau,
    buffer: []const u8,
    ref: i32,
    fbs: std.io.FixedBufferStream([]const u8),
    reader: std.io.FixedBufferStream([]const u8).Reader,

    pub fn init(l: *luau.Luau, index: i32, offset: usize, len: ?usize) !*LReader {
        const context = Context.getContext(l) orelse return error.NoContext;
        const buffer = l.toBuffer(index) catch return error.NotBuffer;
        const self = try LReader.push(l, ReaderBufferRef);
        const rctx = self.erased.as(ReaderBufferRef);
        rctx.* = .{
            .context = context,
            .l = l,
            .buffer = buffer[offset..][0..(len orelse buffer.len - offset)],
            .ref = try l.ref(index),
            .fbs = .{ .buffer = rctx.buffer, .pos = 0 },
            .reader = rctx.fbs.reader(),
        };
        self.reader = rctx.reader.any();
        return self;
    }

    pub fn deinit(self: *ReaderBufferRef) void {
        if (self.context.exiting) return;
        self.l.unref(self.ref);
    }
};

// 1: buffer
// 2: offset?
// 3: length?
fn lReaderFromBuffer(l: *luau.Luau) !i32 {
    const offset: usize = @intFromFloat(l.optNumber(2) orelse 0);
    const length: ?usize = if (l.optNumber(3)) |n| @intFromFloat(n) else null;
    _ = ReaderBufferRef.init(l, 1, offset, length) catch |err| switch (err) {
        error.NotBuffer => return l.argError(1, "expected buffer"),
        else => return err,
    };
    return 1;
}

/// constructed from a luau buffer
const WriterBufferRef = struct {
    context: *const Context,
    l: *luau.Luau,
    buffer: []u8,
    ref: i32,
    fbs: std.io.FixedBufferStream([]u8),
    writer: std.io.FixedBufferStream([]u8).Writer,

    pub fn init(l: *luau.Luau, index: i32, offset: usize, length: ?usize) !*LWriter {
        const context = Context.getContext(l) orelse return error.NoContext;
        const buffer = l.toBuffer(index) catch return error.NotBuffer;
        const self = try LWriter.push(l, WriterBufferRef);
        const wctx = self.erased.as(WriterBufferRef);
        wctx.* = .{
            .context = context,
            .l = l,
            .buffer = buffer[offset..][0..(length orelse buffer.len - offset)],
            .ref = try l.ref(index),
            .fbs = .{ .buffer = wctx.buffer, .pos = 0 },
            .writer = wctx.fbs.writer(),
        };
        self.writer = wctx.writer.any();
        return self;
    }

    pub fn deinit(self: *WriterBufferRef) void {
        if (self.context.exiting) return;
        self.l.unref(self.ref);
    }
};

fn lWriterFromBuffer(l: *luau.Luau) !i32 {
    const offset: usize = @intFromFloat(l.optNumber(2) orelse 0);
    const length: ?usize = if (l.optNumber(3)) |n| @intFromFloat(n) else null;
    _ = WriterBufferRef.init(l, 1, offset, length) catch |err| switch (err) {
        error.NotBuffer => return l.argError(1, "expected buffer"),
        else => return err,
    };
    return 1;
}

// 1: Reader reader
// 2: Writer writer
// 3: ((number) -> boolean)?
// 4: number? buffer_size The size of the buffer to use, defaults to 4096
fn lPipe(l: *luau.Luau) !i32 {
    const reader = l.toUserdata(LReader, 1) catch l.argError(1, "expected reader");
    const writer = l.toUserdata(LWriter, 2) catch l.argError(2, "expected writer");

    const between_fn: ?i32 = switch (l.typeOf(3)) {
        .nil, .none => null,
        .function => 3,
        else => l.argError(3, "expected function or nil"),
    };
    const buffer_size: usize = @intFromFloat(l.optNumber(4) orelse 4096);

    const buffer = l.newBuffer(buffer_size);
    var total: usize = 0;
    while (true) {
        const bytes_read = try reader.reader.read(buffer);
        if (bytes_read == 0) break;
        if (between_fn) |f| {
            l.pushValue(f);
            l.pushNumber(@floatFromInt(bytes_read));
            l.call(1, 1);
            if (!l.toBoolean(-1)) {
                l.pop(2);
                break;
            }
            l.pop(2);
        }
        total += try writer.writer.write(buffer[0..bytes_read]);
    }

    l.pushNumber(@floatFromInt(total));

    return 1;
}

const std = @import("std");
const luau = @import("luau");

const util = @import("../util.zig");

const Context = @import("../Context.zig");
const Platform = @import("../Platform.zig");
