const Self = @This();

require_stack: std.ArrayListUnmanaged(RequireContext) = undefined,
custom_require_handler: ?HandlerFn = null,

pub const Options = struct {
    max_require_depth: usize = 8,
    custom_require_handler: ?HandlerFn = null,
};

pub const HandlerFn = *const fn (l: *luau.Luau, path: []const u8, from: []const u8) ?[]const u8;

pub fn init(allocator: std.mem.Allocator, luau_state: *luau.Luau, options: Options) !Self {
    luau_state.register("require", lRequire);
    return .{
        .require_stack = try std.ArrayListUnmanaged(RequireContext).initCapacity(allocator, options.max_require_depth),
        .custom_require_handler = options.custom_require_handler,
    };
}

pub fn deinit(
    self: *Self,
    allocator: std.mem.Allocator,
) void {
    self.require_stack.deinit(allocator);
}

/// require a relative path without an alias
///
/// returns true if the module was already loaded
pub fn require(context: *Context, l: *luau.Luau, path: []const u8, preload_src: ?[]const u8) Context.Error!bool {
    const modules = getModuleTable(context, l);

    const t = context.temp.allocator();

    const exts: []const []const u8 = &.{ "", ".luau", ".lua", "/init.luau", "/init.lua" };
    inline for (exts) |ext| {
        const ext_path = std.mem.joinZ(t, "", &.{ path, ext }) catch
            l.argError(1, "failed to join path");
        defer t.free(ext_path);

        if (l.getField(modules, ext_path) != .nil) {
            return true;
        }

        if (context.platform.fileExists(ext_path) or preload_src != null) {
            const thread = if (preload_src) |src|
                try context.loadThreadFromString(path, src)
            else
                try context.loadThreadFromFile(ext_path);
            try context.execute(thread);

            const rctx = context.require.require_stack.addOneAssumeCapacity();
            rctx.path = context.allocator.dupeZ(u8, ext_path) catch
                l.argError(1, "failed to dupe path");
            try context.scheduler.schedule(try Scheduler.Thread.init(
                .poll(RequireContext, rctx),
                l,
                thread,
            ));

            return false;
        }
    }

    l.raiseErrorFmt("require {s} failed", .{path}) catch return false;
}

pub const RequireContext = struct {
    path: [:0]u8,

    /// using parent as requirer, using module as state
    pub fn poll(context: *RequireContext, thread: *const Scheduler.Thread, cart_context: *Context) Scheduler.Poll {
        const requirer_thread = thread.state;
        const module_thread = thread.parent.?.state;

        switch (module_thread.status()) {
            .ok => {},
            .yield => return .pending,
            .err_runtime,
            .err_syntax,
            .err_memory,
            .err_error,
            => {
                cart_context.allocator.free(context.path);
                _ = cart_context.require.require_stack.popOrNull();
                requirer_thread.pushString("require failed");
                return .err;
            },
        }
        defer _ = cart_context.require.require_stack.popOrNull();
        defer cart_context.allocator.free(context.path);

        const modules = getModuleTable(cart_context, requirer_thread);
        module_thread.xMove(requirer_thread, 1);
        requirer_thread.pushValue(-1);
        requirer_thread.setField(modules, context.path);

        return .ready(1);
    }
};

/// lua side require function
pub fn lRequire(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    var path = l.toString(1) catch l.argError(1, "expected path as string");
    const source_location = Context.getSourceLocation(l);

    const modules = getModuleTable(context, l);
    const t = context.temp.allocator();

    const preloaded_src = if (context.require.custom_require_handler) |f| f(l, path, source_location) else null;
    const t_dupe_here = if (preloaded_src) |psrc|
        t.dupeZ(u8, psrc) catch l.argError(1, "failed to dupe preloaded source")
    else
        null;

    if (t_dupe_here) |psrc| {
        defer t.free(psrc);

        // get from modules
        if (l.getField(modules, path) != .nil) {
            return 1;
        }

        return if (try require(context, l, path, psrc)) 1 else l.yield(1);
    }

    const ok_path = check: {
        inline for (&.{ "./", "../", "@" }) |prefix| {
            if (std.mem.startsWith(u8, path, prefix)) {
                break :check true;
            }
        }
        break :check false;
    };
    if (!ok_path) {
        l.argError(1, "path must start with ./, ../, or @");
    }

    path = fixPath(t, path) catch l.argError(1, "failed to fix path");
    defer t.free(path);

    const dirname = std.fs.path.dirname(source_location) orelse "";

    for (context.native_aliases.constSlice()) |alias| {
        const prefix = std.fmt.allocPrint(t, "@{s}/", .{alias}) catch
            l.argError(1, "failed to alloc print");
        defer t.free(prefix);

        if (std.mem.startsWith(u8, path, prefix)) {
            if (l.getField(modules, path) != .nil) {
                return 1;
            }

            const err_msg = std.fmt.allocPrintZ(t, "{s} module not found", .{alias}) catch
                l.argError(1, "failed to alloc print");

            l.argError(1, err_msg);
        }
    }

    const resolved_path: []const u8 =
        if (std.mem.startsWith(u8, path, "@"))
    blk: {
        if (l.getField(modules, path) != .nil) {
            return 1;
        }
        const until = std.mem.indexOf(u8, path, "/") orelse path.len;
        const alias = path[1..until];
        const found_alias = context.rc.aliases.get(alias) orelse l.argError(1, "alias does not exist");
        const resolved_path = std.fs.path.joinZ(t, &.{ found_alias, path[until..] }) catch
            l.argError(1, "failed to join path");
        break :blk resolved_path;
    } else std.fs.path.joinZ(t, &.{ dirname, path }) catch
        l.argError(1, "failed to join path");
    defer t.free(resolved_path);

    const fixed_resolved_path = fixPath(t, resolved_path) catch
        l.argError(1, "failed to fix path");
    defer t.free(fixed_resolved_path);

    return if (try require(context, l, fixed_resolved_path, null)) 1 else l.yield(1);
}

const MODULE_TABLE = "_MODULES";
pub fn getModuleTable(context: *Context, l: *luau.Luau) i32 {
    if (context.main_state.getGlobal(MODULE_TABLE) != .table) {
        context.main_state.pop(1);
        context.main_state.newTable();
        context.main_state.setGlobal(MODULE_TABLE);
        _ = context.main_state.getGlobal(MODULE_TABLE);
    }
    context.main_state.xMove(l, 1);
    return l.getTop();
}

pub fn fixPath(allocator: std.mem.Allocator, raw_path: []const u8) ![:0]const u8 {
    var path_processing = raw_path;
    if (std.mem.startsWith(u8, path_processing, "./")) {
        path_processing = path_processing[2..];
    }
    if (std.mem.endsWith(u8, path_processing, "/")) {
        path_processing = path_processing[0 .. path_processing.len - 1];
    }
    const duped = try allocator.dupeZ(u8, path_processing);
    _ = std.mem.replaceScalar(u8, duped, '\\', '/');
    return duped;
}

const std = @import("std");
const luau = @import("luau");

const util = @import("util.zig");

const Context = @import("Context.zig");
const Scheduler = @import("Scheduler.zig");
