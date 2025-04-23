pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/sys")) return;
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
    try context.putCache("cart/sys", .at(-1));
    l.pop(1);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;
