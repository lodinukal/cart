pub fn push(context: *cart.Context) !void {
    const l = context.state;
    l.createPushTable(.{
        .os = @as([]const u8, switch (builtin.os.tag) {
            .windows => "windows",
            .macos => "macos",
            .linux => switch (builtin.abi) {
                .android => "android",
                else => "linux",
            },
            .ios => "ios",
            .wasi => "wasi",
            else => "unknown",
        }),
    }, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/sys");
    try push(context);
    luau.require.registermodule(context.state);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;
