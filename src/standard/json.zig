pub const MAX_KEY_LENGTH = 512;

pub fn open(l: *luau.Luau) void {
    l.newTable();

    l.pushString("encode");
    l.pushFunction(lEncode, "@cart/json.encode");
    l.setTable(-3);

    l.pushString("decode");
    l.pushFunction(lDecode, "@cart/json.decode");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

fn encodeArrayPortion(l: *luau.Luau, allocator: std.mem.Allocator, index: i32) error{ OutOfMemory, Fail }!std.json.Value {
    const len = l.objLen(index);
    var array: std.ArrayList(std.json.Value) = try .initCapacity(allocator, @intCast(len));
    errdefer array.deinit();

    for (0..@as(usize, @intCast(len))) |i| {
        _ = l.rawGetIndex(index, @intCast(i + 1));
        const value = try encode(l, allocator, -1);
        try array.append(value);
        l.pop(1);
    }

    return .{
        .array = array,
    };
}

fn encodeObjectPortion(l: *luau.Luau, allocator: std.mem.Allocator, index: i32) error{ OutOfMemory, Fail }!std.json.Value {
    l.pushValue(index);
    l.pushNil();
    var decided: std.json.ObjectMap = .init(allocator);
    errdefer decided.deinit();

    while (l.next(-2)) {
        l.pushValue(-2);
        const key = try l.toString(-1);
        const value = try encode(l, allocator, -2);
        try decided.put(key, value);
        l.pop(2);
    }
    l.pop(1);

    return .{
        .object = decided,
    };
}

fn encode(l: *luau.Luau, allocator: std.mem.Allocator, index: i32) !std.json.Value {
    const ty = l.typeOf(index);
    switch (ty) {
        .none => {
            return .null;
        },
        .nil => {
            return .null;
        },
        .boolean => {
            const value = l.toBoolean(index);
            return .{
                .bool = value,
            };
        },
        .light_userdata => {
            return .null;
        },
        .number => {
            const value = try l.toNumber(index);
            if (value == @trunc(value)) {
                return .{
                    .integer = @intFromFloat(value),
                };
            }
            return .{
                .float = value,
            };
        },
        .vector => {
            const value = try l.toVector(index);
            var duped: std.ArrayList(std.json.Value) = try .initCapacity(allocator, value.len);
            errdefer duped.deinit();

            for (value) |item| {
                duped.appendAssumeCapacity(.{ .float = item });
            }

            return .{
                .array = duped,
            };
        },
        .string => {
            const value = try l.toString(index);
            return .{
                .string = value,
            };
        },
        .table => {
            var decided: union(enum) {
                unknown: void,
                array: std.json.Array,
                object: std.json.ObjectMap,
            } = .unknown;
            errdefer switch (decided) {
                .array => decided.array.deinit(),
                .object => decided.object.deinit(),
                else => {},
            };

            const is_array = l.objLen(index) != 0;

            if (is_array) {
                return try encodeArrayPortion(l, allocator, index);
            } else {
                return try encodeObjectPortion(l, allocator, index);
            }
        },
        .function => {
            return .null;
        },
        .userdata => {
            return .null;
        },
        .thread => {
            return .null;
        },
        .buffer => {
            return .null;
        },
    }
}

fn decode(l: *luau.Luau, value: std.json.Value) !void {
    var buffer: [MAX_KEY_LENGTH]u8 = @splat(0);
    switch (value) {
        .null => {
            l.pushNil();
        },
        .bool => {
            l.pushBoolean(value.bool);
        },
        .integer => {
            l.pushInteger(@intCast(value.integer));
        },
        .float => {
            l.pushNumber(value.float);
        },
        .number_string => {
            l.pushNumber(std.fmt.parseFloat(f64, value.number_string) catch |err| {
                return err;
            });
        },
        .string => {
            l.pushLString(value.string);
        },
        .array => {
            l.newTable();
            for (value.array.items) |item| {
                try decode(l, item);
                l.rawSetIndex(-2, l.objLen(-2) + 1);
            }
        },
        .object => {
            l.newTable();
            var it = value.object.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                if (key.len >= MAX_KEY_LENGTH) {
                    return error.InvalidKeyLength;
                }
                @memcpy(buffer[0..key.len], key);
                buffer[key.len] = 0;
                const item = entry.value_ptr.*;
                try decode(l, item);
                l.setField(-2, @ptrCast(buffer[0..key.len]));
            }
        },
    }
}

fn lEncode(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    _ = context;

    var arena: std.heap.ArenaAllocator = .init(l.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const value = try encode(l, allocator, 1);

    const str = try std.json.stringifyAlloc(allocator, value, .{});
    l.pushString(try allocator.dupeZ(u8, str));
    return 1;
}

fn lDecode(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    _ = context;
    const str = l.checkString(1);
    const value = try std.json.parseFromSlice(std.json.Value, l.allocator(), str, .{
        .duplicate_field_behavior = .use_first,
    });
    defer value.deinit();

    try decode(l, value.value);

    return 1;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
