pub const Context = @import("Context.zig");
pub const require = @import("require.zig");
pub const luau = @import("luau");
pub const util = @import("util.zig");

pub const modules = struct {
    pub const ast = @import("modules/ast.zig");
    pub const sys = @import("modules/sys.zig");
    pub const fs = @import("modules/fs.zig");
    pub const pretty = @import("modules/pretty.zig");
};

comptime {
    _ = Context;
    _ = require;
    _ = util;
}
