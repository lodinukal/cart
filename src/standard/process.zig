const PROCESS_CHILD_METATABLE = "@cart/process.Child";

pub const LChild = struct {
    l: *luau.Luau,
    child: ?std.process.Child,
    term: ?std.process.Child.Term,
    // refs
    stdin: ?i32 = null,
    stdout: ?i32 = null,
    stderr: ?i32 = null,
    done: std.atomic.Value(bool) = .init(false),

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(PROCESS_CHILD_METATABLE) catch @panic("failed to create process child metatable");
        l.pushString(PROCESS_CHILD_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        util.pushFunction(l, lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        util.pushFunction(l, lWait, "wait");
        l.setField(-2, "wait");

        util.pushFunction(l, lKill, "kill");
        l.setField(-2, "kill");

        util.pushFunction(l, lTerm, "term");
        l.setField(-2, "term");

        util.pushFunction(l, lStdin, "stdin");
        l.setField(-2, "stdin");

        util.pushFunction(l, lStdout, "stdout");
        l.setField(-2, "stdout");

        util.pushFunction(l, lStderr, "stderr");
        l.setField(-2, "stderr");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("@cart/process.Child");
        return 1;
    }

    pub fn push(l: *luau.Luau, child: std.process.Child) *LChild {
        const lchild: *LChild = l.newUserdataDtor(LChild, deinit);
        _ = l.getMetatableRegistry(PROCESS_CHILD_METATABLE);
        l.setMetatable(-2);
        lchild.* = .{
            .l = l,
            .child = child,
            .term = null,
        };

        return lchild;
    }

    pub fn deinit(self: *LChild) void {
        if (self.child) |c| {
            self.child = null;
            var copy = c;
            _ = copy.wait() catch {};
        }

        const context = Context.getContext(self.l) orelse return;
        if (context.exiting) return;

        if (self.stdin) |w| {
            self.l.unref(w);
            self.stdin = null;
        }

        if (self.stdout) |r| {
            self.l.unref(r);
            self.stdout = null;
        }

        if (self.stderr) |r| {
            self.l.unref(r);
            self.stderr = null;
        }
    }

    fn lKill(l: *luau.Luau) !i32 {
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.child) |*c| {
            self.term = try c.kill();
            self.deinit();
        } else {
            l.argError(1, "child already closed");
        }
        return 0;
    }

    fn lWait(l: *luau.Luau) !i32 {
        const context = Context.getContext(l) orelse return 0;
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.done.load(.acquire)) {
            pushTerm(l, self.term.?);
            return 1;
        }
        if (self.child) |*c| {
            if (Platform.is_wasm) {
                self.term = try c.wait();
                pushTerm(l, self.term.?);
                self.child = null;
                self.deinit();
                return 1;
            } else {
                const thread = std.Thread.spawn(.{
                    .stack_size = 1024,
                    .allocator = l.allocator(),
                }, spawn, .{self}) catch return error.OutOfMemory;
                thread.detach();
                try context.scheduler.schedule(try Scheduler.Thread.init(.poll(LChild, self), l, l));
                return l.yield(1);
            }
        } else {
            l.argError(1, "child already closed");
        }
        return 0;
    }

    // used on non wasi systems
    pub fn spawn(child: *LChild) !void {
        defer {
            child.child = null;
            child.deinit();
            child.done.store(true, .release);
        }
        child.term = try child.child.?.wait();
    }

    // used on non wasi systems
    pub fn poll(context: *LChild, thread: *const Scheduler.Thread, _: Context) Scheduler.Poll {
        if (context.done.load(.acquire)) {
            if (context.term) |t| {
                pushTerm(thread.state, t);
            } else {
                thread.state.pushNil();
            }
            return .ready(1);
        }

        return .pending;
    }

    fn lTerm(l: *luau.Luau) !i32 {
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.term) |t| {
            pushTerm(l, t);
            return 1;
        } else {
            l.pushNil();
            return 1;
        }
    }

    fn lStdin(l: *luau.Luau) !i32 {
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.stdin) |w| {
            _ = l.rawGetIndex(luau.REGISTRYINDEX, w);
            return 1;
        } else {
            l.pushNil();
            return 1;
        }
    }

    fn lStdout(l: *luau.Luau) !i32 {
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.stdout) |r| {
            _ = l.rawGetIndex(luau.REGISTRYINDEX, r);
            return 1;
        } else {
            l.pushNil();
            return 1;
        }
    }

    fn lStderr(l: *luau.Luau) !i32 {
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.stderr) |r| {
            _ = l.rawGetIndex(luau.REGISTRYINDEX, r);
            return 1;
        } else {
            l.pushNil();
            return 1;
        }
    }
};

pub fn pushTerm(l: *luau.Luau, term: std.process.Child.Term) void {
    l.newTable();

    switch (term) {
        inline else => |code, tag| {
            l.pushString(switch (tag) {
                .Exited => "exited",
                .Signal => "signal",
                .Stopped => "stopped",
                .Unknown => "unknown",
            });
            l.setField(-2, "type");
            l.pushInteger(@intCast(code));
            l.setField(-2, "code");
        },
    }
}

pub fn open(l: *luau.Luau) void {
    if (std.process.can_spawn) {
        LChild.open(l);
    }

    l.newTable();

    l.pushString("argv");
    util.pushFunction(l, lArgv, "@cart/process.argv");
    l.setTable(-3);

    l.pushString("getenv");
    util.pushFunction(l, lGetenv, "@cart/process.getenv");
    l.setTable(-3);

    l.pushString("exit");
    util.pushFunction(l, lExit, "@cart/process.exit");
    l.setTable(-3);

    l.pushString("spawn");
    util.pushFunction(l, lSpawn, "@cart/process.spawn");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

fn lArgv(l: *luau.Luau) !i32 {
    var args_it = try std.process.argsWithAllocator(l.allocator());
    defer args_it.deinit();

    l.newTable();

    var index: i32 = 1;
    while (args_it.next()) |arg| {
        l.pushString(arg);
        l.rawSetIndex(-2, index);
        index += 1;
    }

    return 1;
}

fn lGetenv(l: *luau.Luau) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const key = l.checkString(1);
    const lallocator = l.allocator();
    const t = context.temp.allocator();
    if (try std.process.hasEnvVar(lallocator, key)) {
        const temp = try std.process.getEnvVarOwned(lallocator, key);
        defer lallocator.free(temp);

        const duped = t.dupeZ(u8, temp) catch return 0;
        defer t.free(duped);
        l.pushString(duped);
    } else {
        l.pushNil();
    }
    return 1;
}

fn lExit(l: *luau.Luau) !i32 {
    const code = if (l.getTop() < 1) 0 else try l.toInteger(1);
    std.process.exit(@intCast(code));
}

// 1: string, executable name
// 2: array of arguments
fn lSpawn(l: *luau.Luau) !i32 {
    if (!std.process.can_spawn) {
        try l.raiseErrorFmt("process spawning is not supported on this platform", .{});
    }
    const context = Context.getContext(l) orelse return 0;
    const name = l.checkString(1);

    const t = context.temp.allocator();
    var args = std.ArrayList([]const u8).init(t);
    defer args.deinit();

    try args.append(name);

    const lallocator = l.allocator();

    switch (l.typeOf(2)) {
        .table => {
            l.pushValue(2);
            l.pushNil();
            while (l.next(-2)) {
                const str = l.checkString(-1);
                try args.append(str);
                l.pop(1);
            }
        },
        else => {
            l.argError(2, "expected table");
        },
    }

    const options = parseSpawnOptions(l, t, 3) catch |err| {
        switch (err) {
            error.NotATable => l.argError(3, "expected table"),
            error.InvalidEnumValue => l.argError(3, "invalid enum value"),
            else => return err,
        }
    };
    var c = std.process.Child.init(args.items, lallocator);

    c.cwd = options.cwd;
    c.env_map = &options.env;
    c.stdin_behavior = options.stdin.toZig();
    c.stdout_behavior = options.stdout.toZig();
    c.stderr_behavior = options.stderr.toZig();
    try c.spawn();

    const lchild = LChild.push(l, c);
    if (lchild.child.?.stdin) |stdin| {
        _ = try io.LWriter.pushWriter(l, stdin.writer());
        lchild.stdin = try l.ref(-1);
        l.pop(1);
    }
    if (lchild.child.?.stdout) |stdout| {
        _ = try io.LReader.pushReader(l, stdout.reader());
        lchild.stdout = try l.ref(-1);
        l.pop(1);
    }
    if (lchild.child.?.stderr) |stderr| {
        _ = try io.LReader.pushReader(l, stderr.reader());
        lchild.stderr = try l.ref(-1);
        l.pop(1);
    }

    return 1;
}

pub const IoBehavior = enum {
    inherit,
    ignore,
    pipe,

    pub inline fn toZig(self: IoBehavior) std.process.Child.StdIo {
        switch (self) {
            .inherit => return .Inherit,
            .ignore => return .Ignore,
            .pipe => return .Pipe,
        }
    }
};

pub const SpawnOptions = struct {
    cwd: ?[]const u8 = null,
    env: std.process.EnvMap,
    stdin: IoBehavior = .inherit,
    stdout: IoBehavior = .inherit,
    stderr: IoBehavior = .inherit,
};

pub fn parseSpawnOptions(l: *luau.Luau, allocator: std.mem.Allocator, index: i32) !SpawnOptions {
    switch (l.typeOf(index)) {
        .table => {},
        else => return error.NotATable,
    }

    var options: SpawnOptions = .{
        .env = .init(allocator),
    };
    switch (try l.getFieldObjConsumed(index, "cwd")) {
        .string => |s| {
            options.cwd = try allocator.dupe(u8, s);
        },
        .nil, .none => {},
        else => l.argError(index, "expected string for cwd"),
    }

    switch (try l.getFieldObj(index, "env")) {
        .table => {
            defer l.pop(1);

            l.pushNil();
            while (l.next(-2)) {
                const key = try allocator.dupe(u8, try l.toString(-2));
                const value = try allocator.dupe(u8, try l.toString(-1));
                try options.env.put(key, value);
                l.pop(1);
            }
        },
        .nil, .none => {},
        else => l.argError(index, "expected table for env"),
    }

    switch (try l.getFieldObj(index, "stdin")) {
        .string => |s| {
            options.stdin = std.meta.stringToEnum(IoBehavior, s) orelse return error.InvalidEnumValue;
        },
        .nil, .none => {},
        else => l.argError(index, "expected string for stdin"),
    }

    switch (try l.getFieldObj(index, "stdout")) {
        .string => |s| {
            options.stdout = std.meta.stringToEnum(IoBehavior, s) orelse return error.InvalidEnumValue;
        },
        .nil, .none => {},
        else => l.argError(index, "expected string for stdout"),
    }

    switch (try l.getFieldObj(index, "stderr")) {
        .string => |s| {
            options.stderr = std.meta.stringToEnum(IoBehavior, s) orelse return error.InvalidEnumValue;
        },
        .nil, .none => {},
        else => l.argError(index, "expected string for stderr"),
    }

    return options;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Platform = @import("../Platform.zig");
const Scheduler = @import("../Scheduler.zig");

const util = @import("../util.zig");
const io = @import("io.zig");
