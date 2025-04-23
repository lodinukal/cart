// implements require mechanism using zig file system.

// ! is an invalid character in requires; we can safely use it as a prefix
pub const preload_tag = "!";

pub fn preloadedCache(allocator: std.mem.Allocator, key: []const u8) ![:0]const u8 {
    return try std.mem.joinZ(allocator, "/", &.{ preload_tag, key });
}

pub fn preloadedCacheComptime(comptime key: []const u8) []const u8 {
    return std.fmt.comptimePrint("{s}/{s}", .{ preload_tag, key });
}

pub fn preloadedKVComptime(
    comptime key: []const u8,
) []const u8 {
    return std.fmt.comptimePrint("{s}={s}/{s}", .{ key, preload_tag, key });
}

pub const State = struct {
    fba: std.heap.FixedBufferAllocator = .init(&.{}),
    compile_options: luau.CompileOptions = .{},
    stringified_luaurc: []const u8 = "",

    cwd: std.fs.Dir = undefined,

    abs_path: ?[:0]const u8 = null,
    rel_path: ?[:0]const u8 = null,
    suffix: ?[:0]const u8 = null,

    is_preloaded: bool = false,

    // called when a module yields
    on_yield: ?*const fn (*State) void = null,

    pub fn init(
        cwd: std.fs.Dir,
        buffer: []u8,
        compile_options: luau.CompileOptions,
        luaurc: []const u8,
    ) !State {
        return .{
            .fba = .init(buffer),
            .compile_options = compile_options,
            .stringified_luaurc = luaurc,
            .cwd = cwd,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.fba.reset();
    }

    pub fn setAbsPath(self: *@This(), new_path: []const u8) !void {
        self.abs_path = try self.fba.allocator().dupeZ(u8, new_path);
    }

    pub fn setRelPath(self: *@This(), new_path: []const u8) !void {
        self.rel_path = try self.fba.allocator().dupeZ(u8, new_path);
    }
};

pub const config: luau.require.Configuration = .{
    .is_require_allowed = @ptrCast(&isRequireAllowed),
    .reset = @ptrCast(&reset),
    .jump_to_alias = @ptrCast(&jumpToAlias),
    .to_parent = @ptrCast(&toParent),
    .to_child = @ptrCast(&toChild),
    .is_module_present = @ptrCast(&isModulePresent),
    .get_contents = @ptrCast(&getContents),
    .get_chunkname = @ptrCast(&getChunkname),
    .get_cache_key = @ptrCast(&getCacheKey),
    .is_config_present = @ptrCast(&isConfigPresent),
    .get_config = @ptrCast(&getConfig),
    .load = @ptrCast(&load),
};

const suffixes: []const [:0]const u8 = &.{ ".luau", ".lua" };
const folder_suffixes: []const [:0]const u8 = &.{ "init.luau", "init.lua" };

fn getSuffixWithAmbiguityCheck(cwd: std.fs.Dir, path: []const u8, allocator: std.mem.Allocator) !struct { luau.require.NavigateResult, ?[:0]const u8 } {
    var found = false;
    var found_suffix: ?[:0]const u8 = null;

    for (suffixes) |suffix| {
        const suffix_path = try std.mem.joinZ(allocator, "", &.{ path, suffix });
        defer allocator.free(suffix_path);

        const stat = cwd.statFile(suffix_path) catch continue;
        if (stat.kind == .file) {
            if (found) {
                return .{ .ambiguous, null };
            }
            found = true;
            found_suffix = suffix;
        }
    }

    if (cwd.statFile(path)) |outer_stat| {
        if (outer_stat.kind == .directory) {
            if (found) {
                return .{ .ambiguous, null };
            }

            for (folder_suffixes) |sub_suffix| {
                const sub_suffix_path = try joinZ(allocator, &.{ path, sub_suffix });
                defer allocator.free(sub_suffix_path);

                const stat = cwd.statFile(sub_suffix_path) catch continue;
                if (stat.kind == .file) {
                    if (found) {
                        return .{ .ambiguous, null };
                    }
                    found = true;
                    found_suffix = sub_suffix;
                }
            }
        }
    } else |_| {}

    if (!found) {
        return .{ .not_found, null };
    }

    return .{ .success, found_suffix };
}

fn addSuffix(cwd: std.fs.Dir, partial_result: PathResult, allocator: std.mem.Allocator, skip: bool) !PathResult {
    if (partial_result.status != .success or skip) {
        return partial_result;
    }

    const status, const suffix = try getSuffixWithAmbiguityCheck(
        cwd,
        partial_result.abs_path orelse "",
        allocator,
    );
    if (status != .success) {
        return partial_result;
    }

    var new_result = partial_result;
    new_result.suffix = suffix;
    return new_result;
}

fn stdinResult(cwd: std.fs.Dir, allocator: std.mem.Allocator) !PathResult {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_path = try cwd.realpath("", &path_buf);
    return .{
        .status = .success,
        .abs_path = try joinZ(allocator, &.{ cwd_path, "stdin" }),
        .rel_path = try allocator.dupeZ(u8, "stdin"),
        .suffix = try allocator.dupeZ(u8, ""),
    };
}

fn absolutePathResult(cwd: std.fs.Dir, allocator: std.mem.Allocator, path: []const u8, skip_suffix: bool) !PathResult {
    return try addSuffix(cwd, .{
        .status = .success,
        .abs_path = try allocator.dupeZ(u8, path),
    }, allocator, skip_suffix);
}

fn relativePathResult(cwd: std.fs.Dir, allocator: std.mem.Allocator, path: []const u8) !PathResult {
    if (std.fs.path.isAbsolute(path)) {
        return absolutePathResult(cwd, allocator, path, false);
    }

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_path = try cwd.realpath("", &path_buf);
    const resolved_abs_path = try joinZ(allocator, &.{ cwd_path, path });

    return try addSuffix(cwd, .{
        .status = .success,
        .abs_path = resolved_abs_path,
    }, allocator, false);
}

fn getParent(cwd: std.fs.Dir, allocator: std.mem.Allocator, abs_path: []const u8, rel_path: []const u8, skip_suffix: bool) !PathResult {
    var component_it = try std.fs.path.componentIterator(abs_path);
    _ = component_it.last();
    if (component_it.previous()) |component| {
        const parent_path = component.path;
        return try addSuffix(cwd, .{
            .status = .success,
            .abs_path = try allocator.dupeZ(u8, parent_path),
            .rel_path = try joinZ(allocator, &.{ rel_path, "../" }),
        }, allocator, skip_suffix);
    }
    return .{
        .status = .not_found,
    };
}

fn getChild(cwd: std.fs.Dir, allocator: std.mem.Allocator, abs_path: []const u8, rel_path: []const u8, name: []const u8, skip_suffix: bool) !PathResult {
    const abs_joined_path = try joinZ(allocator, &.{ abs_path, name });
    const rel_joined_path = try joinZ(allocator, &.{ rel_path, name });
    return try addSuffix(cwd, .{
        .status = .success,
        .abs_path = abs_joined_path,
        .rel_path = rel_joined_path,
    }, allocator, skip_suffix);
}

pub const PathResult = struct {
    status: luau.require.NavigateResult = .success,
    abs_path: ?[:0]const u8 = null,
    rel_path: ?[:0]const u8 = null,
    suffix: ?[:0]const u8 = null,

    pub fn deinit(self: PathResult, allocator: std.mem.Allocator) void {
        if (self.abs_path) |abs_path| {
            allocator.free(abs_path);
        }
        if (self.rel_path) |rel_path| {
            allocator.free(rel_path);
        }
    }

    pub fn setAbsPath(self: *PathResult, allocator: std.mem.Allocator, new_path: []const u8) !void {
        if (self.abs_path) |abs_path| {
            allocator.free(abs_path);
        }
        self.abs_path = try allocator.dupeZ(u8, new_path);
    }

    pub fn setRelPath(self: *PathResult, allocator: std.mem.Allocator, new_path: []const u8) !void {
        if (self.rel_path) |rel_path| {
            allocator.free(rel_path);
        }
        self.rel_path = try allocator.dupeZ(u8, new_path);
    }
};

fn storePathResult(context: *State, result: PathResult) !luau.require.NavigateResult {
    const allocator = context.fba.allocator();
    defer result.deinit(allocator);
    switch (result.status) {
        .ambiguous, .not_found => {
            return result.status;
        },
        else => {
            try context.setAbsPath(result.abs_path orelse "");
            try context.setRelPath(result.rel_path orelse "");
            context.suffix = result.suffix orelse null;
            return .success;
        },
    }
}

fn write(contents: []const u8, buffer: [*]u8, buffer_size: usize, size_out: *usize) luau.require.WriteResult {
    if (buffer_size < contents.len) {
        size_out.* = contents.len;
        return .buffer_too_small;
    }

    size_out.* = contents.len;
    @memcpy(buffer[0..contents.len], contents);
    return .success;
}

pub fn initFunction(
    in_config: *luau.require.Configuration,
) callconv(.c) void {
    in_config.* = config;
}

fn isRequireAllowed(
    l: *luau.State,
    context: *State,
    requirer_chunkname: [*:0]const u8,
) callconv(.c) bool {
    _ = l;
    _ = context;
    const chunkname: []const u8 = std.mem.span(requirer_chunkname);
    return std.mem.eql(u8, chunkname, "=stdin") or
        std.mem.startsWith(u8, chunkname, "@");
}

fn reset(
    _: *luau.State,
    context: *State,
    requirer_chunkname: [*:0]const u8,
) callconv(.c) luau.require.NavigateResult {
    context.fba.reset();
    const allocator = context.fba.allocator();
    const chunkname = std.mem.span(requirer_chunkname);

    context.is_preloaded = false;

    if (std.mem.eql(u8, chunkname, "=stdin")) {
        return storePathResult(context, stdinResult(context.cwd, allocator) catch return .not_found) catch {
            return .not_found;
        };
    } else if (std.mem.startsWith(u8, chunkname, "@")) {
        return storePathResult(context, relativePathResult(context.cwd, allocator, chunkname[1..]) catch
            return .not_found) catch {
            return .not_found;
        };
    }
    return .not_found;
}

fn jumpToAlias(
    _: *luau.State,
    context: *State,
    path: [*:0]const u8,
) callconv(.c) luau.require.NavigateResult {
    const allocator = context.fba.allocator();
    const path_str = std.mem.span(path);

    if (std.mem.startsWith(u8, path_str, preload_tag)) {
        context.is_preloaded = true;
    }

    const result = storePathResult(
        context,
        absolutePathResult(
            context.cwd,
            allocator,
            path_str,
            context.is_preloaded,
        ) catch
            return .not_found,
    ) catch {
        return .not_found;
    };
    if (result != .success) {
        return result;
    }

    context.setAbsPath(path_str) catch {
        return .not_found;
    };
    return .success;
}

fn toParent(
    _: *luau.State,
    context: *State,
) callconv(.c) luau.require.NavigateResult {
    const allocator = context.fba.allocator();

    return storePathResult(
        context,
        getParent(
            context.cwd,
            allocator,
            context.abs_path orelse "",
            context.rel_path orelse "",
            context.is_preloaded,
        ) catch
            return .not_found,
    ) catch {
        return .not_found;
    };
}

fn toChild(
    _: *luau.State,
    context: *State,
    name: [*:0]const u8,
) callconv(.c) luau.require.NavigateResult {
    const allocator = context.fba.allocator();

    return storePathResult(
        context,
        getChild(
            context.cwd,
            allocator,
            context.abs_path orelse "",
            context.rel_path orelse "",
            std.mem.span(name),
            context.is_preloaded,
        ) catch
            return .not_found,
    ) catch {
        return .not_found;
    };
}

fn isModulePresent(
    _: *luau.State,
    context: *State,
) callconv(.c) bool {
    const allocator = context.fba.allocator();

    const check_path = std.mem.joinZ(allocator, "", &.{
        context.abs_path orelse "",
        context.suffix orelse "",
    }) catch return false;
    defer allocator.free(check_path);

    if (context.is_preloaded) {
        return true;
    }

    const stat = context.cwd.statFile(check_path) catch return false;
    return stat.kind == .file;
}

fn getContents(
    l: *luau.State,
    context: *State,
    buffer: [*]u8,
    buffer_size: usize,
    size_out: *usize,
) callconv(.c) luau.require.WriteResult {
    const allocator = context.fba.allocator();

    const check_path = std.mem.joinZ(allocator, "", &.{
        context.abs_path orelse "",
        context.suffix orelse "",
    }) catch return .failure;
    defer allocator.free(check_path);

    const lallocator = l.allocator();
    const whole_file = context.cwd.readFileAlloc(
        lallocator,
        check_path,
        std.math.maxInt(u64),
    ) catch |err| {
        std.log.err("Error loading {s}: {}\n", .{ check_path, err });
        return .failure;
    };
    defer lallocator.free(whole_file);

    return write(whole_file, buffer, buffer_size, size_out);
}

fn getChunkname(
    _: *luau.State,
    context: *State,
    buffer: [*:0]u8,
    buffer_size: usize,
    size_out: *usize,
) callconv(.c) luau.require.WriteResult {
    var current_size = buffer_size;
    var size_out_one: usize = 0;
    const write_at = write("@", buffer, current_size, &size_out_one);
    if (write_at != .success) {
        return write_at;
    }
    current_size -= size_out_one;
    const chunkname = context.rel_path orelse "";
    const write_chunkname = write(chunkname, buffer[size_out_one..], current_size, &size_out_one);
    if (write_chunkname != .success) {
        return write_chunkname;
    }
    current_size -= size_out_one;
    size_out.* = buffer_size - current_size;
    return .success;
}

fn getCacheKey(
    _: *luau.State,
    context: *State,
    buffer: [*:0]u8,
    buffer_size: usize,
    size_out: *usize,
) callconv(.c) luau.require.WriteResult {
    const allocator = context.fba.allocator();

    const check_path = std.mem.joinZ(allocator, "", &.{
        context.abs_path orelse "",
        context.suffix orelse "",
    }) catch return .failure;
    defer allocator.free(check_path);

    return write(check_path, buffer, buffer_size, size_out);
}

fn isConfigPresent(_: *luau.State, _: *State) callconv(.c) bool {
    // return true because we always have a config
    return true;
}

const default_config =
    \\{}
;

fn getConfig(
    _: *luau.State,
    context: *State,
    buffer: [*:0]u8,
    buffer_size: usize,
    size_out: *usize,
) callconv(.c) luau.require.WriteResult {
    return write(context.stringified_luaurc, buffer, buffer_size, size_out);
}

fn load(
    l: *luau.State,
    context: *State,
    chunkname: [*:0]const u8,
    contents: [*:0]const u8,
) callconv(.c) i32 {
    const allocator = context.fba.allocator();
    const chunkname_str = std.mem.span(chunkname);
    const contents_str = std.mem.span(contents);

    var success = false;

    const g = l.mainThread() catch unreachable;
    const m = g.initThread() catch return 0;
    defer if (!success) m.deinit();
    g.xmove(l, 1);

    m.sandboxThread();

    const lallocator = l.allocator();
    const bytecode = luau.compile(
        lallocator,
        lallocator,
        contents_str,
        context.compile_options,
    ) catch return 0;
    defer bytecode.deinit(lallocator);

    var erred = false;
    if (m.load(chunkname_str, bytecode.bytes)) {
        // TODO codegen + coverage

        const status = m.@"resume"(l, 0);
        if (status == .running) {
            if (m.getTop() == .none) {
                m.pushLengthString("module must return a value");
                erred = true;
            }
        } else if (status == .suspended) {
            if (context.on_yield) |on_yield| {
                on_yield(context);
            } else {
                m.pushLengthString("top level yield not handled");
                erred = true;
            }
        } else if (!m.isString(.at(-1))) {
            m.pushLengthString("unknown error while running module");
            erred = true;
        }
    }

    m.xmove(l, 1);
    if (erred) {
        // must do this here, l.err will not return back
        bytecode.deinit(allocator);
        l.err();
    }

    l.remove(.at(-2));
    success = true;

    return 1;
}

const luau = @import("luau");
const std = @import("std");

pub fn joinZ(allocator: std.mem.Allocator, paths: []const []const u8) ![:0]u8 {
    const out = try joinSepMaybeZ(allocator, '/', std.fs.path.isSep, paths, true);
    return out[0 .. out.len - 1 :0];
}

// from std
/// This is different from mem.join in that the separator will not be repeated if
/// it is found at the end or beginning of a pair of consecutive paths.
fn joinSepMaybeZ(allocator: std.mem.Allocator, separator: u8, comptime sepPredicate: fn (u8) bool, paths: []const []const u8, zero: bool) ![]u8 {
    if (paths.len == 0) return if (zero) try allocator.dupe(u8, &[1]u8{0}) else &[0]u8{};

    // Find first non-empty path index.
    const first_path_index = blk: {
        for (paths, 0..) |path, index| {
            if (path.len == 0) continue else break :blk index;
        }

        // All paths provided were empty, so return early.
        return if (zero) try allocator.dupe(u8, &[1]u8{0}) else &[0]u8{};
    };

    // Calculate length needed for resulting joined path buffer.
    const total_len = blk: {
        var sum: usize = paths[first_path_index].len;
        var prev_path = paths[first_path_index];
        std.debug.assert(prev_path.len > 0);
        var i: usize = first_path_index + 1;
        while (i < paths.len) : (i += 1) {
            const this_path = paths[i];
            if (this_path.len == 0) continue;
            const prev_sep = sepPredicate(prev_path[prev_path.len - 1]);
            const this_sep = sepPredicate(this_path[0]);
            sum += @intFromBool(!prev_sep and !this_sep);
            sum += if (prev_sep and this_sep) this_path.len - 1 else this_path.len;
            prev_path = this_path;
        }

        if (zero) sum += 1;
        break :blk sum;
    };

    const buf = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buf);

    @memcpy(buf[0..paths[first_path_index].len], paths[first_path_index]);
    var buf_index: usize = paths[first_path_index].len;
    var prev_path = paths[first_path_index];
    std.debug.assert(prev_path.len > 0);
    var i: usize = first_path_index + 1;
    while (i < paths.len) : (i += 1) {
        const this_path = paths[i];
        if (this_path.len == 0) continue;
        const prev_sep = sepPredicate(prev_path[prev_path.len - 1]);
        const this_sep = sepPredicate(this_path[0]);
        if (!prev_sep and !this_sep) {
            buf[buf_index] = separator;
            buf_index += 1;
        }
        const adjusted_path = if (prev_sep and this_sep) this_path[1..] else this_path;
        @memcpy(buf[buf_index..][0..adjusted_path.len], adjusted_path);
        buf_index += adjusted_path.len;
        prev_path = this_path;
    }

    if (zero) buf[buf.len - 1] = 0;

    // No need for shrink since buf is exactly the correct size.
    return buf;
}
