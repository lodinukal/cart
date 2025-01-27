pub const Config = struct {
    arena: std.heap.ArenaAllocator,
    aliases: std.StringArrayHashMapUnmanaged([]const u8),

    pub fn parse(long_allocator: std.mem.Allocator, temp_allocator: std.mem.Allocator, source: []const u8) !Config {
        const parsed = try std.json.parseFromSlice(std.json.Value, temp_allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
            .duplicate_field_behavior = .use_last,
        });
        defer parsed.deinit();

        var result: Config = .{
            .arena = std.heap.ArenaAllocator.init(long_allocator),
            .aliases = .{},
        };
        const allocator = result.arena.allocator();

        if (parsed.value != .object) return error.InvalidLuaurc;
        const root_object = parsed.value.object;
        var root_it = root_object.iterator();

        while (root_it.next()) |kv| {
            if (std.mem.eql(u8, kv.key_ptr.*, "aliases")) {
                if (kv.value_ptr.* != .object) return error.InvalidLuaurc;
                const aliases_object = kv.value_ptr.*.object;
                var aliases_it = aliases_object.iterator();
                while (aliases_it.next()) |alias_kv| {
                    if (alias_kv.value_ptr.* != .string) return error.InvalidLuaurc;
                    const from = alias_kv.key_ptr.*;
                    const to = alias_kv.value_ptr.*.string;
                    try result.aliases.put(allocator, try allocator.dupe(u8, from), try allocator.dupe(u8, to));
                }
            }
        }
        return result;
    }

    pub fn deinit(self: *Config) void {
        self.arena.deinit();
    }
};

const std = @import("std");
// const Platform = @import("Platform.zig");
