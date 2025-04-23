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

pub inline fn pushErrorUnion(l: *luau.State, comptime T: type, err_union: T, diagnostics: ?*Diagnostics) void {
    const allocator = l.allocator();
    const joined: []const u8 = if (diagnostics) |diag| blk: {
        break :blk std.mem.join(allocator, "\n", diag.msgs.items) catch "";
    } else "";
    defer allocator.free(joined);

    if (@as(T, err_union)) |good| {
        l.createPushTable(.{
            .ok = true,
            .value = good,
        }, null);
    } else |bad| {
        l.createPushTable(.{
            .ok = false,
            .why = @as([]const u8, @errorName(bad)),
            .explanation = joined,
        }, null);
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

    pub inline fn push(self: *Diagnostics, comptime fmt: []const u8, args: anytype) !void {
        const allocator = self.fba.allocator();
        const msg = try std.fmt.allocPrint(allocator, fmt, args);
        try self.msgs.append(allocator, msg);
    }
};

pub inline fn returnErrorUnion(l: *luau.State, comptime T: type, err_union: T, diagnostics: ?*Diagnostics) i32 {
    pushErrorUnion(l, T, err_union, diagnostics);
    return 1;
}

pub inline fn returnValue(l: *luau.State, comptime T: type, value: T) i32 {
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

const std = @import("std");
const cart = @import("root.zig");
const luau = cart.luau;
