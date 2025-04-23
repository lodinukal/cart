pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/pretty")) return;
    const l = context.state;

    const allocator = l.allocator();
    const bc = try luau.compile(allocator, allocator, SOURCE, .{});
    defer bc.deinit(allocator);

    if (l.load("@!/cart/pretty", bc.bytes) == false) {
        return error.UnableToLoadModule;
    }
    l.call(0, 1);
    l.setReadonly(.at(-1), true);
    try context.putCache("cart/pretty", .at(-1));
    l.pop(1);
}

const SOURCE = @embedFile("pretty.luau");

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;
