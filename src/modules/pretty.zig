pub fn push(context: *cart.Context) !void {
    const l = context.state;

    const allocator = l.allocator();
    const bc = try luau.compile(allocator, allocator, SOURCE, .{});
    defer bc.deinit(allocator);

    if (l.load("@cart/pretty", bc.bytes) == false) {
        return error.UnableToLoadModule;
    }
    l.call(0, 1);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/pretty");
    try push(context);
    luau.require.registermodule(context.state);
}

const SOURCE = @embedFile("pretty.luau");

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;
