// note: CONTEXT IS PINNED IT MUST NOT BE MOVED ONCE .init() IS CALLED

tpool: xev.ThreadPool,
loop: xev.Loop,
asynchronous: xev.Async,

cwd: std.fs.Dir = undefined,

/// extra valid aliases
stringified_luaurc: []u8 = "",
extra_aliases: std.StringArrayHashMapUnmanaged(?[]const u8) = .empty,
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

    self.extra_aliases = .empty;

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

    try self.extra_aliases.ensureUnusedCapacity(alloc, aliases.value_ptr.object.count());
    var alias_iter = aliases.value_ptr.object.iterator();
    while (alias_iter.next()) |entry| {
        // const alias = entry.key_ptr;
        // const path = entry.value.string orelse return error.InvalidAlias;
        // if (alias == null) continue;
        const alias_point_to = entry.value_ptr.string;
        self.extra_aliases.putAssumeCapacityNoClobber(entry.key_ptr.*, if (alias_point_to.len == 0) null else alias_point_to);
    }

    const stringified = try std.json.stringifyAlloc(alloc, as_json.value, .{
        .whitespace = .minified,
    });
    self.require_state = try .init(
        std.fs.cwd(),
        try alloc.alloc(u8, config.max_require_path_working_bytes),
        config.compile_options,
        stringified,
        self.extra_aliases,
    );

    // self should be pinned
    const l = try luau.State.init(&self.allocator);
    l.open(.{});
    // self should be pinned
    luau.require.open(l, require.initFunction, @ptrCast(&self.require_state));

    l.pushLightUserdata(@ptrCast(self));
    l.setField(.registry, registry_tag);

    self.* = .{
        .tpool = .init(.{}),
        .loop = try .init(.{
            .thread_pool = &self.tpool,
        }),
        .asynchronous = try .init(),
        .cwd = std.fs.cwd(),
        .stringified_luaurc = stringified,
        .extra_aliases = self.extra_aliases,
        .allocator = self.allocator,
        .state = l,
        .compile_options = config.compile_options,
        .require_state = self.require_state,
        .exiting = false,
    };
}

pub fn deinit(self: *@This()) void {
    self.exiting = true;
    _ = self.state.gc(.collect);
    self.allocator.free(self.stringified_luaurc);
    self.allocator.free(self.require_state.fba.buffer);
    self.require_state.deinit();

    self.extra_aliases.deinit(self.allocator);

    self.asynchronous.deinit();
    self.loop.run(.until_done) catch |err| {
        std.debug.print("Error while running loop: {}\n", .{err});
    };
    self.loop.deinit();
    self.state.deinit();

    self.tpool.shutdown();
    self.tpool.deinit();

    self.* = undefined;
}

pub fn fromState(state: *luau.State) !*Context {
    _ = state.getField(.registry, registry_tag);
    defer state.pop(1);
    return @ptrCast(@alignCast(state.toLightUserdata(.at(-1)) orelse return error.InvalidState));
}

pub fn setWorkingDirectory(self: *@This(), dir: std.fs.Dir) void {
    self.require_state.cwd = dir;
    self.cwd = dir;
}

const luau = @import("luau");
const std = @import("std");
const xev = @import("xev");

const Context = @This();

const require = @import("require.zig");
