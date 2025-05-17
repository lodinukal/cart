const cart = @import("cart");

const allocator = std.heap.c_allocator;

// pub const Config = struct {
//     read_luaurc: []const u8 = "{}",
//     /// "alias1=value", "alias2=value", etc.
//     extra_aliases: []const []const u8 = &.{},
//     compile_options: luau.CompileOptions = .{},
//     max_require_path_working_bytes: usize = 1024,
// };

pub const CompileOptions = extern struct {
    optimization_level: i32 = 1,
    debug_level: i32 = 1,
    coverage_level: i32 = 0,
    /// global builtin to construct vectors; disabled by default (<vector_lib>.<vector_ctor>)
    vector_lib: ?[*:0]const u8 = null,
    vector_ctor: ?[*:0]const u8 = null,
    /// vector type name for type tables; disabled by default
    vector_type: ?[*:0]const u8 = null,
    /// null-terminated array of globals that are mutable; disables the import optimization for fields accessed through these
    mutable_globals: ?[*:null]const ?[*:0]const u8 = null,
};

pub const Config = extern struct {
    luaurc: Slice(u8),
    extra_aliases: Slice(Slice(u8)),
    compile_options: CompileOptions,
    max_require_path_working_bytes: usize = 1024,
};

/// creates a new cart context; use `cart_destroycontext` to destroy it
export fn cart_createcontext(config: *const Config, out_context: *?*cart.Context) callconv(.c) bool {
    var extra_aliases_list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer extra_aliases_list.deinit(allocator);
    for (config.extra_aliases.to()) |alias| {
        extra_aliases_list.append(allocator, alias.to()) catch return false;
    }

    out_context.* = cart.Context.create(allocator, .{
        .read_luaurc = config.luaurc.to(),
        .extra_aliases = extra_aliases_list.items,
        .compile_options = .{
            .optimization_level = config.compile_options.optimization_level,
            .debug_level = config.compile_options.debug_level,
            .coverage_level = config.compile_options.coverage_level,
            .vector_lib = config.compile_options.vector_lib,
            .vector_ctor = config.compile_options.vector_ctor,
            .vector_type = config.compile_options.vector_type,
            .mutable_globals = config.compile_options.mutable_globals,
        },
        .max_require_path_working_bytes = config.max_require_path_working_bytes,
    }) catch return false;
    return true;
}

/// destroys the cart context
export fn cart_destroycontext(context: *cart.Context) callconv(.c) void {
    context.destroy();
}

/// gets the current cart context from the luau state
export fn cart_contextfromstate(opt_state: ?*cart.luau.State) callconv(.c) ?*cart.Context {
    const state = opt_state orelse return null;
    const context = cart.Context.fromState(state) catch return null;
    return context;
}

/// gets the current luau state from the cart context
export fn cart_statefromcontext(context: ?*cart.Context) callconv(.c) ?*cart.luau.State {
    return (context orelse return null).state;
}

// modules
export fn cart_openfs(context: *cart.Context) callconv(.c) bool {
    cart.modules.fs.open(context) catch return false;
    return true;
}

export fn cart_opennet(context: *cart.Context) callconv(.c) bool {
    cart.modules.net.open(context) catch return false;
    return true;
}

export fn cart_openresult(context: *cart.Context) callconv(.c) bool {
    cart.modules.result.open(context) catch return false;
    return true;
}

export fn cart_openpretty(context: *cart.Context) callconv(.c) bool {
    cart.modules.pretty.open(context) catch return false;
    return true;
}

export fn cart_openstream(context: *cart.Context) callconv(.c) bool {
    cart.modules.stream.open(context) catch return false;
    return true;
}

export fn cart_opensys(context: *cart.Context) callconv(.c) bool {
    cart.modules.sys.open(context) catch return false;
    return true;
}

export fn cart_openast(context: *cart.Context) callconv(.c) bool {
    cart.modules.ast.open(context) catch return false;
    return true;
}

export fn cart_openall(context: *cart.Context) callconv(.c) bool {
    if (cart_openfs(context) == false) return false;
    if (cart_opennet(context) == false) return false;
    if (cart_openresult(context) == false) return false;
    if (cart_openpretty(context) == false) return false;
    if (cart_openstream(context) == false) return false;
    if (cart_opensys(context) == false) return false;
    if (cart_openast(context) == false) return false;
    return true;
}

/// external constant slice
pub fn Slice(comptime T: type) type {
    return extern struct {
        pub const Ptr = ?[*]const T;
        pub const ZigSlice = []const T;

        ptr: Ptr = null,
        len: usize = 0,

        pub inline fn one(ptr: *const T) @This() {
            return .{ .ptr = @ptrCast(ptr), .len = 1 };
        }

        pub inline fn from(slice: ZigSlice) @This() {
            return .{ .ptr = slice.ptr, .len = slice.len };
        }

        pub inline fn to(self: @This()) ZigSlice {
            return if (self.ptr) |ptr| ptr[0..self.len] else &.{};
        }
    };
}

/// external mutable slice
pub fn MutableSlice(comptime T: type) type {
    return extern struct {
        pub const Ptr = ?[*]T;
        pub const ZigSlice = []T;

        ptr: Ptr = null,
        len: usize = 0,

        pub inline fn one(ptr: *const T) @This() {
            return .{ .ptr = @ptrCast(ptr), .len = 1 };
        }

        pub inline fn from(slice: ZigSlice) @This() {
            return .{ .ptr = slice.ptr, .len = slice.len };
        }

        pub inline fn to(self: @This()) ZigSlice {
            return if (self.ptr) |ptr| ptr[0..self.len] else &.{};
        }
    };
}

const std = @import("std");
