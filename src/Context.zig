const Self = @This();

pub const Error = Scheduler.Error || luau.Error || Platform.Error || error{};
const CART_GLOBAL_NAME = "__CART";
const MAX_NATIVE_ALIASES = 16;

rc: luaurc.Config,

allocator: std.mem.Allocator,
platform: Platform,
options: Options,

delta_time: f64 = 0.1,

native_aliases: std.BoundedArray([]const u8, MAX_NATIVE_ALIASES) = .{},
main_state: *luau.Luau = undefined,
require: Require = undefined,
temp: Temp = undefined,
scheduler: Scheduler = undefined,

exiting: bool = false,

pub const Options = struct {
    luau_libs: luau.Libs = .{
        .base = true,
        .string = true,
        .utf8 = true,
        .table = true,
        .math = true,
        .io = true,
        .os = true,
        .debug = true,
        .bit32 = true,
        .buffer = true,
        .vector = true,
    },
    require: Require.Options,
    temp: Temp.Options,
    scheduler: Scheduler.Options,
};

/// self should be pinned
pub fn init(self: *Self) Error!void {
    const luau_state = try luau.Luau.init(&self.allocator);
    errdefer luau_state.deinit();

    // define __CART as a global
    luau_state.newMetatable(CART_GLOBAL_NAME) catch return error.OutOfMemory;
    _ = luau_state.pushString(CART_GLOBAL_NAME);
    luau_state.setField(-2, "__type");
    _ = luau_state.pushString("This metatable is locked.");
    luau_state.setField(-2, "__metatable");
    luau_state.setReadOnly(-1, true);

    luau_state.pushLightUserdata(@ptrCast(self));
    _ = luau_state.getMetatableRegistry(CART_GLOBAL_NAME);
    luau_state.setMetatable(-2);
    luau_state.setGlobal(CART_GLOBAL_NAME);

    luau_state.open(self.options.luau_libs);
    luau_state.openCoroutine();

    self.* = .{
        .rc = self.rc,
        .allocator = self.allocator,
        .platform = self.platform,
        .options = self.options,

        .main_state = luau_state,
        .temp = try Temp.init(self.allocator, self.options.temp),
        .require = try Require.init(self.allocator, luau_state, self.options.require),
        .scheduler = .{
            .allocator = self.allocator,
            .options = self.options.scheduler,
            .main_state = luau_state,
        },
    };

    try self.scheduler.init();
}

pub fn deinit(self: *Self) void {
    self.exiting = true;
    self.scheduler.deinit();
    self.temp.deinit(self.allocator);
    self.require.deinit(self.allocator);
    self.main_state.deinit();
}

pub const Module = struct {
    name: [:0]const u8,
    open: fn (*luau.Luau) void,
};

pub const modules = struct {
    pub const ffi = @import("standard/ffi.zig");
    pub const io = @import("standard/io.zig");
    pub const fs = @import("standard/fs.zig");
    pub const sys = @import("standard/sys.zig");
    pub const task = @import("standard/task.zig");
    pub const net = @import("standard/net.zig");
    pub const web = @import("standard/web.zig");
    pub const process = @import("standard/process.zig");
};

pub const CART_MODULES: []const Module = &[_]Module{
    .{ .name = "ffi", .open = modules.ffi.open },
    .{ .name = "io", .open = modules.io.open },
    .{ .name = "fs", .open = modules.fs.open },
    .{ .name = "sys", .open = modules.sys.open },
    .{ .name = "task", .open = modules.task.open },
    .{ .name = "net", .open = modules.net.open },
    .{ .name = "web", .open = modules.web.open },
    .{ .name = "process", .open = modules.process.open },
};

pub fn loadCartStandard(self: *Self) !void {
    try self.loadLibrary("cart", CART_MODULES);
}

pub fn loadLibrary(self: *Self, comptime alias: []const u8, comptime m: []const Module) !void {
    const module_table = Require.getModuleTable(self, self.main_state);
    try self.native_aliases.append(alias);
    inline for (m) |module| {
        const name = module.name;
        module.open(self.main_state);

        const qualified_name = "@" ++ alias ++ "/" ++ name;
        self.main_state.setField(module_table, qualified_name);
        // std.log.info("Loaded cart library: {s} -> {s}", .{ name, qualified_name });
    }
}

/// gets the context from the current thread, used for lua functions
pub fn getContext(l: *luau.Luau) ?*Self {
    defer l.pop(1);
    if (l.getGlobal(CART_GLOBAL_NAME) != .light_userdata) {
        return null;
    }
    return l.checkUserdata(Self, -1, CART_GLOBAL_NAME);
}

/// returns true if there is no more work to be done for the context
pub fn isWorkDone(self: *const Self) bool {
    return self.scheduler.working.items.len == 0 and self.scheduler.waiting.items.len == 0;
}

/// polls the scheduler
pub fn poll(self: *Self) Error!void {
    try self.scheduler.poll(self);
}

/// loads bytecode from file
///
/// result is temporary, dupe if needed
pub fn loadBytecodeFromFile(self: *Self, path: []const u8, options: luau.CompileOptions) Error![]const u8 {
    const got = try self.platform.openFile(path, .{
        .create_if_not_exists = false,
    });
    defer self.platform.closeFile(got);

    const t = self.temp.allocator();
    const reader = try got.reader(self.platform);
    const source = reader.readAllAlloc(t, std.math.maxInt(u16)) catch return error.OutOfMemory;

    return try luau.compile(t, source, options);
}

/// loads bytecode from string
///
/// result is temporary, dupe if needed
pub fn loadBytecodeFromString(self: *Self, source: []const u8, options: luau.CompileOptions) Error![]const u8 {
    const t = self.temp.allocator();
    return try luau.compile(t, source, options);
}

pub const SOURCE_GLOBAL_NAME = "__SOURCE";
pub const SOURCE_PATH_NAME = "path";

/// loads bytecode into a thread
pub fn loadThread(self: *Self, path: []const u8, bytecode: []const u8) Error!*luau.Luau {
    const thread = self.main_state.newThread();
    thread.sandboxThread();
    const pathZ = try Require.fixPath(self.temp.allocator(), path);
    try thread.loadBytecode(pathZ, bytecode);
    thread.setSafeEnv(luau.GLOBALSINDEX, true);

    thread.newTable();
    thread.setFieldString(-1, SOURCE_PATH_NAME, pathZ);
    thread.setReadOnly(-1, true);
    thread.setField(luau.GLOBALSINDEX, SOURCE_GLOBAL_NAME);

    return thread;
}

/// gets the source of the current thread
///
/// result is temporary, dupe if needed
pub fn getSourceLocation(thread: *luau.Luau) []const u8 {
    if (thread.getGlobal(SOURCE_GLOBAL_NAME) != .table) {
        thread.pop(1);
        return "";
    }
    if (thread.getField(-1, SOURCE_PATH_NAME) != .string) {
        thread.pop(2);
        return "";
    }
    const path = thread.toString(-1) catch "";
    thread.pop(2);
    return path;
}

/// utility function to load a thread from a file
pub fn loadThreadFromFile(self: *Self, path: []const u8) Error!*luau.Luau {
    const bytecode = try self.loadBytecodeFromFile(path, .{});
    return self.loadThread(path, bytecode);
}

/// utility function to load a thread from a string
pub fn loadThreadFromString(self: *Self, path: []const u8, source: []const u8) Error!*luau.Luau {
    const bytecode = try self.loadBytecodeFromString(source, .{});
    return self.loadThread(path, bytecode);
}

/// adds an entry thread (thread which has no parent and may spawn children) to the scheduler
pub fn execute(self: *Self, thread: *luau.Luau) Error!void {
    try self.scheduler.schedule(try Scheduler.Thread.init(
        .instant,
        thread,
        self.main_state,
    ));
}

const std = @import("std");

const luau = @import("luau");

const luaurc = @import("luaurc.zig");
const Platform = @import("Platform.zig");
const Require = @import("Require.zig");
const Scheduler = @import("Scheduler.zig");
const Temp = @import("Temp.zig");

const util = @import("util.zig");
