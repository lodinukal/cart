pub fn push(context: *cart.Context) !void {
    const l = context.state;
    l.createPushTable(.{}, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/result");
    try push(context);
    luau.require.registermodule(context.state);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const util = cart.util;
