// note: CONTEXT IS PINNED IT MUST NOT BE MOVED ONCE .init() IS CALLED

// loop: xev.Loop,

cwd: std.fs.Dir = undefined,

/// extra valid aliases
stringified_luaurc: []u8 = "",
/// pinned allocator; we cannot pass the allocator to luau directly, so we
/// pin it to the Context
allocator: std.mem.Allocator = undefined,

/// main luau state
state: *luau.State = undefined,
compile_options: luau.CompileOptions = .{},

/// if the context is exiting; i.e. on the next tick of the event loop it will be
/// deinitialized
exiting: bool = false,

/// stores the current require state
require_state: require.State = .{},

pub const Config = struct {
    read_luaurc: []const u8 = "{}",
    /// "alias1=value", "alias2=value", etc.
    extra_aliases: []const []const u8 = &.{},
    compile_options: luau.CompileOptions = .{},
    max_require_path_working_bytes: usize = 1024,
};

pub fn create(alloc: std.mem.Allocator, config: Config) !*Context {
    const ctx = try alloc.create(Context);
    try ctx.init(alloc, config);
    return ctx;
}

pub fn destroy(self: *@This()) void {
    const allocator = self.allocator;
    self.deinit();
    allocator.destroy(self);
}

const registry_tag = "_CART";

pub fn init(self: *@This(), alloc: std.mem.Allocator, config: Config) !void {
    self.allocator = alloc;

    var as_json = try std.json.parseFromSlice(
        std.json.Value,
        alloc,
        config.read_luaurc,
        .{
            .allocate = .alloc_always,
            .duplicate_field_behavior = .use_first,
        },
    );
    defer as_json.deinit();

    const aliases = try as_json.value.object.getOrPut("aliases");
    if (!aliases.found_existing) {
        aliases.value_ptr.* = .{ .object = .init(as_json.arena.allocator()) };
    }

    for (config.extra_aliases) |combined_alias_path| {
        var split = std.mem.splitScalar(u8, combined_alias_path, '=');
        const alias = split.next() orelse return error.InvalidAlias;
        const optional_path = split.next() orelse "";
        try aliases.value_ptr.object.putNoClobber(alias, .{ .string = optional_path });
    }

    const stringified = try std.json.stringifyAlloc(alloc, as_json.value, .{
        .whitespace = .minified,
    });
    self.require_state = try .init(
        std.fs.cwd(),
        try alloc.alloc(u8, config.max_require_path_working_bytes),
        config.compile_options,
        stringified,
    );

    // self should be pinned
    const l = try luau.State.init(&self.allocator);
    l.open(.{});
    // self should be pinned
    luau.require.open(l, require.initFunction, @ptrCast(&self.require_state));

    l.pushLightUserdata(@ptrCast(self));
    l.setField(.registry, registry_tag);

    self.* = .{
        // .loop = try .init(.{}),
        .cwd = std.fs.cwd(),
        .stringified_luaurc = stringified,
        .allocator = self.allocator,
        .state = l,
        .compile_options = config.compile_options,
        .require_state = self.require_state,
        .exiting = false,
    };
}

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.stringified_luaurc);
    self.allocator.free(self.require_state.fba.buffer);
    self.require_state.deinit();
    self.state.deinit();

    // self.loop.deinit();

    self.* = undefined;
}

pub fn fromState(state: *luau.State) !*Context {
    _ = state.getField(.registry, registry_tag);
    return @ptrCast(@alignCast(state.toLightUserdata(.at(-1)) orelse return error.InvalidState));
}

pub fn setWorkingDirectory(self: *@This(), dir: std.fs.Dir) void {
    self.require_state.cwd = dir;
    self.cwd = dir;
}

pub fn run(_: *@This()) !void {
    // try self.loop.run(.no_wait);
}

pub fn runUntilDone(_: *@This()) !void {
    // try self.loop.run(.until_done);
}

pub fn isDone(_: *@This()) bool {
    // return self.loop.done();
    return true;
}

const luau = @import("luau");
const std = @import("std");
// const xev = @import("xev");

const Context = @This();

const require = @import("require.zig");
