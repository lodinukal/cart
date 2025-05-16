// utilities for reading and creating streams

pub fn push(context: *cart.Context) !void {
    const l = context.state;
    l.createPushTable(.{}, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/stream");
    try push(context);
    luau.require.registermodule(context.state);
}

pub const reader_read_fn_key = "read";
pub const writer_write_fn_key = "write";
pub const seek_fn_key = "seek";
pub const tell_fn_key = "tell";

pub const Error = error{
    InvalidReader,
    InvalidWriter,
};

pub const Kind = enum {
    reader,
    writer,
};

// if it conforms it will push the corresponding read/write function to the stack
pub fn conformsto(l: *luau.State, at: luau.vm.Index, kind: Kind) bool {
    if (l.type(at) != .table) {
        l.pop(1);
        return false;
    }
    if (l.getField(at, switch (kind) {
        .reader => reader_read_fn_key,
        .writer => writer_write_fn_key,
    }) != .function) {
        l.pop(1);
        return false;
    }
    return true;
}

pub fn isseekable(l: *luau.State, at: luau.vm.Index) enum { ok, no_seek, no_tell, not_a_stream } {
    if (l.type(at) != .table) {
        l.pop(1);
        return .not_a_stream;
    }
    if (l.getField(at, seek_fn_key) != .function) {
        l.pop(1);
        return .no_seek;
    }
    defer l.pop(1);
    if (l.getField(at, tell_fn_key) != .function) {
        l.pop(1);
        return .no_tell;
    }
    defer l.pop(1);
    return .ok;
}

pub fn MarshalResult(comptime Config: type) type {
    const T: type = @field(Config, "Type");
    const unmarshal: fn (l: *luau.State, at: luau.vm.Index) ?T = @field(Config, "unmarshal");
    return union(enum) {
        ok: T,
        err: struct {
            why: []const u8,
            explanation: []const u8,
        },

        pub fn from(l: *luau.State, at: luau.vm.Index) !@This() {
            // on top of stack should be a result type, check if its a table
            if (l.type(at) != .table) {
                return error.Invalid;
            }
            // has fields, ok + value, or ok + why + explanation
            if (l.getField(at, "ok") != .boolean) {
                return error.Invalid;
            }
            const ok = l.toBoolean(.at(-1));
            l.pop(1);
            if (ok) {
                // read value
                _ = l.getField(at, "value");
                if (unmarshal(l, .at(-1))) |value| {
                    l.pop(1);
                    return .{ .ok = value };
                }
                return error.Invalid;
            } else {
                // read why + explanation
                if (l.getField(.at(-1), "why") != .string) {
                    return error.Invalid;
                }
                const why = l.toLengthString(.at(-1));
                l.pop(1);
                if (l.getField(.at(-1), "explanation") != .string) {
                    return error.Invalid;
                }
                const explanation = l.toLengthString(.at(-1));
                l.pop(1);
                return .{ .err = .{
                    .why = why,
                    .explanation = explanation,
                } };
            }
        }
    };
}

pub const UsizeResult = MarshalResult(struct {
    pub const Type = usize;
    pub fn unmarshal(l: *luau.State, at: luau.vm.Index) ?usize {
        if (l.type(at) != .number) {
            return null;
        }
        const n = l.toIntegerx(at) orelse return null;
        return @intCast(n);
    }
});

pub const VoidResult = MarshalResult(struct {
    pub const Type = void;
    pub fn unmarshal(_: *luau.State, _: luau.vm.Index) ?void {
        return {};
    }
});

pub fn read(l: *luau.State, reader: luau.vm.Index, into: luau.vm.Index) UsizeResult {
    if (!conformsto(l, reader, .reader)) return .{ .err = .{
        .why = "InvalidReader",
        .explanation = "Reader does not conform to the reader interface",
    } };
    // shift -1 because conformsto adds to the stack
    l.pushIndex(reader.shiftIfNegative(-1));
    // shift -2 because conformsto AND the above push
    l.pushIndex(into.shiftIfNegative(-2));
    switch (l.pcall(2, 1, .none)) {
        .ok => {},
        .yield => {
            @panic("Yield not supported yet");
        },
        else => {
            if (l.isString(.at(-1))) {
                const string = l.toLengthString(.at(-1));
                return .{ .err = .{
                    .why = "ReadError",
                    .explanation = string,
                } };
            } else {
                return .{ .err = .{
                    .why = "InvalidReaderResult",
                    .explanation = "Unexpected",
                } };
            }
        },
    }
    const result: UsizeResult = UsizeResult.from(l, .at(-1)) catch return .{ .err = .{
        .why = "InvalidReaderResult",
        .explanation = "Returned value is not a valid result",
    } };
    return result;
}

pub fn write(l: *luau.State, writer: luau.vm.Index, from: luau.vm.Index) UsizeResult {
    if (!conformsto(l, writer, .writer)) return .{ .err = .{
        .why = "InvalidWriter",
        .explanation = "Writer does not conform to the writer interface",
    } };
    // shift -1 because conformsto adds to the stack
    l.pushIndex(writer.shiftIfNegative(-1));
    // shift -2 because conformsto AND the above push
    l.pushIndex(from.shiftIfNegative(-2));
    switch (l.pcall(2, 1, .none)) {
        .ok => {},
        .yield => {
            @panic("Yield not supported yet");
        },
        else => {
            if (l.isString(.at(-1))) {
                const string = l.toLengthString(.at(-1));
                return .{ .err = .{
                    .why = "WriteError",
                    .explanation = string,
                } };
            } else {
                return .{ .err = .{
                    .why = "InvalidWriterResult",
                    .explanation = "Unexpected",
                } };
            }
        },
    }
    const result: UsizeResult = UsizeResult.from(l, .at(-1)) catch return .{ .err = .{
        .why = "InvalidWriterResult",
        .explanation = "Returned value is not a valid result",
    } };
    return result;
}

pub fn seek(l: *luau.State, stream: luau.vm.Index, offset: usize) VoidResult {
    const seek_status = isseekable(l, stream);
    if (seek_status != .ok) return .{ .err = .{
        .why = "InvalidStream",
        .explanation = switch (seek_status) {
            .no_seek => "Stream does not support seeking",
            .no_tell => "Stream does not support telling",
            .not_a_stream => "Not a stream",
            .ok => unreachable,
        },
    } };
    _ = l.getField(stream, seek_fn_key);
    // shift -1 because above push adds to the stack
    l.pushIndex(stream.shiftIfNegative(-1));
    l.pushInteger(@intCast(offset));
    switch (l.pcall(2, 1, .none)) {
        .ok => {},
        .yield => {
            @panic("Yield not supported yet");
        },
        else => {
            if (l.isString(.at(-1))) {
                const string = l.toLengthString(.at(-1));
                return .{ .err = .{
                    .why = "SeekError",
                    .explanation = string,
                } };
            } else {
                return .{ .err = .{
                    .why = "InvalidSeekResult",
                    .explanation = "Unexpected",
                } };
            }
        },
    }
    return .{ .ok = {} };
}

// tell: fn (stream) -> usize
pub fn tell(l: *luau.State, stream: luau.vm.Index) UsizeResult {
    const seek_status = isseekable(l, stream);
    if (seek_status != .ok) return .{ .err = .{
        .why = "InvalidStream",
        .explanation = switch (seek_status) {
            .no_seek => "Stream does not support seeking",
            .no_tell => "Stream does not support telling",
            .not_a_stream => "Not a stream",
            .ok => unreachable,
        },
    } };
    _ = l.getField(stream, tell_fn_key);
    // shift -1 because above push adds to the stack
    l.pushIndex(stream.shiftIfNegative(-1));
    switch (l.pcall(1, 1, .none)) {
        .ok => {},
        .yield => {
            @panic("Yield not supported yet");
        },
        else => {
            if (l.isString(.at(-1))) {
                const string = l.toLengthString(.at(-1));
                return .{ .err = .{
                    .why = "TellError",
                    .explanation = string,
                } };
            } else {
                return .{ .err = .{
                    .why = "InvalidTellResult",
                    .explanation = "Unexpected",
                } };
            }
        },
    }
    const result: UsizeResult = UsizeResult.from(l, .at(-1)) catch return .{ .err = .{
        .why = "InvalidTellResult",
        .explanation = "Returned value is not a valid result",
    } };
    return result;
}

comptime {
    _ = write;
    _ = read;
    _ = seek;
    _ = tell;
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const util = cart.util;
