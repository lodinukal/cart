pub fn open(l: *luau.Luau) void {
    const lallocator = l.allocator();
    const bc = luau.compile(lallocator, SOURCE, .{}) catch @panic("failed to compile pretty module");
    defer lallocator.free(bc);

    l.loadBytecode("@cart/pretty", bc) catch @panic("failed to load pretty module");
    l.call(0, 1);
    l.setReadOnly(-1, true);
}

const SOURCE = @embedFile("pretty.luau");

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
