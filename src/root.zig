pub const Context = @import("Context.zig");
pub const require = @import("require.zig");
pub const luau = @import("luau");
pub const util = @import("util.zig");

pub const xev = @import("xev");

pub const modules = struct {
    pub const ast = @import("modules/ast.zig");
    pub const fs = @import("modules/fs.zig");
    pub const net = @import("modules/net.zig");
    pub const pretty = @import("modules/pretty.zig");
    pub const result = @import("modules/result.zig");
    pub const stream = @import("modules/stream.zig");
    pub const sys = @import("modules/sys.zig");
    pub const task = @import("modules/task.zig");
};

pub const UserdataTag = enum(u8) {
    fs_file = 1,
    net_socket = 2,
};

comptime {
    _ = Context;
    _ = require;
    _ = util;
}
