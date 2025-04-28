pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/result")) return;
    const l = context.state;
    l.createPushTable(.{}, null);
    l.setReadonly(.at(-1), true);
    try context.putCache("cart/result", .at(-1));
    l.pop(1);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const util = cart.util;
