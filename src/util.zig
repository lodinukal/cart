pub fn tostring(l: *luau.State, index: luau.vm.Index) [:0]const u8 {
    const fallback_type_name = @tagName(l.type(index));
    _ = l.getGlobal("tostring");
    l.pushIndex(index.shiftIfNegative(-1));
    if (l.pcall(1, 1, .none) != .ok) {
        return fallback_type_name;
    }
    const str = l.toLengthString(.at(-1));
    l.pop(1);
    return str;
}

pub fn pushOk(l: *luau.State, comptime T: type, value: T, stack_offset: ?i32) void {
    l.createPushTable(.{
        .ok = true,
        .value = value,
    }, stack_offset);
}

pub fn pushError(l: *luau.State, err: []const u8, diagnostics: ?*Diagnostics, stack_offset: ?i32) void {
    const allocator = l.allocator();
    const joined: []const u8 = if (diagnostics) |diag| blk: {
        break :blk std.mem.join(allocator, "\n", diag.msgs.items) catch "";
    } else "";
    defer allocator.free(joined);

    l.createPushTable(.{
        .ok = false,
        .why = @as([]const u8, err),
        .explanation = joined,
    }, stack_offset);
}

pub fn pushErrorUnion(l: *luau.State, comptime T: type, err_union: T, diagnostics: ?*Diagnostics) void {
    if (@as(T, err_union)) |good| {
        pushOk(l, @TypeOf(good), good, null);
    } else |bad| {
        pushError(l, @errorName(bad), diagnostics, null);
    }
}

pub const Diagnostics = struct {
    pub const max_diagnostic_length = 4096;

    buffer: [max_diagnostic_length]u8 = undefined,
    fba: std.heap.FixedBufferAllocator = .init(&.{}),
    msgs: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn init(self: *Diagnostics) void {
        self.* = .{
            .fba = .init(&self.buffer),
        };
        self.msgs.ensureTotalCapacity(self.fba.allocator(), 5) catch unreachable;
    }

    pub fn deinit(self: *Diagnostics) void {
        self.* = undefined;
    }

    pub fn reset(self: *Diagnostics) void {
        self.msgs.clearAndFree(self.fba.allocator());
        self.fba.reset();
    }

    pub fn push(self: *Diagnostics, comptime fmt: []const u8, args: anytype) !void {
        const allocator = self.fba.allocator();
        const msg = try std.fmt.allocPrint(allocator, fmt, args);
        try self.msgs.append(allocator, msg);
    }
};

pub fn returnErrorUnion(l: *luau.State, comptime T: type, err_union: T, diagnostics: ?*Diagnostics) i32 {
    pushErrorUnion(l, T, err_union, diagnostics);
    return 1;
}

pub fn returnValue(l: *luau.State, comptime T: type, value: T) i32 {
    l.pushVal(value, null);
    return 1;
}

pub fn dumpstack(l: *luau.State) void {
    if (l.checkStack(3) == false) return;
    const top = l.getTop();
    const bottom = 1;
    _ = l.getGlobal("tostring");
    var i: i32 = top.int();
    while (i >= bottom) : (i -= 1) {
        l.pushIndex(.at(-1));
        l.pushIndex(.at(@intCast(i)));
        if (l.pcall(1, 1, .none) != .ok) {
            l.pop(2);
            // pops result and tostring
        }
        const str = l.toLengthString(.at(-1));
        std.log.warn("{d}: {s}", .{ i, str });
        l.pop(1);
    }
    l.pop(1);
}

pub const Ref = struct {
    l: *luau.State,
    index: i32,

    pub fn init(l: *luau.State, index: luau.vm.Index) !Ref {
        const r = l.ref(index);
        if (r == 0) return error.InvalidRef;
        return .{
            .l = l,
            .index = r,
        };
    }

    pub fn deinit(self: *Ref) void {
        self.l.unref(self.index);
        self.* = undefined;
    }

    pub fn push(self: Ref) void {
        _ = self.l.rawGeti(.registry, self.index);
    }
};

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

const std = @import("std");
const cart = @import("root.zig");
const luau = cart.luau;
