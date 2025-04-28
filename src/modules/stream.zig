// utilities for reading and creating streams

pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/stream")) return;
    const l = context.state;
    l.createPushTable(.{}, null);
    l.setReadonly(.at(-1), true);
    try context.putCache("cart/stream", .at(-1));
    l.pop(1);
}

pub const reader_read_fn_key = "read";
pub const writer_write_fn_key = "write";

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
    if (l.type(at) != .table) return false;
    if (l.getField(at, switch (kind) {
        .reader => reader_read_fn_key,
        .writer => writer_write_fn_key,
    }) != .function) {
        l.pop(1);
        return false;
    }
    return true;
}

pub const Result = union(enum) {
    ok: usize,
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
            // read value as an integer
            if (l.getField(at, "value") != .number) {
                return error.Invalid;
            }
            const n = l.toIntegerx(.at(-1)) orelse return error.Invalid;
            l.pop(1);
            return .{ .ok = @intCast(n) };
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

pub fn read(l: *luau.State, reader: luau.vm.Index, into: luau.vm.Index) Result {
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
    const result: Result = Result.from(l, .at(-1)) catch return .{ .err = .{
        .why = "InvalidReaderResult",
        .explanation = "Returned value is not a valid result",
    } };
    return result;
}

pub fn write(l: *luau.State, writer: luau.vm.Index, from: luau.vm.Index) Result {
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
    const result: Result = Result.from(l, .at(-1)) catch return .{ .err = .{
        .why = "InvalidWriterResult",
        .explanation = "Returned value is not a valid result",
    } };
    return result;
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const util = cart.util;
