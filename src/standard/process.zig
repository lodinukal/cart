const PROCESS_CHILD_METATABLE = "@cart/process.Child";

pub const LChild = struct {
    child: ?std.process.Child,
    term: ?std.process.Child.Term,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(PROCESS_CHILD_METATABLE) catch @panic("failed to create process child metatable");
        l.pushString(PROCESS_CHILD_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lWait, "wait");
        l.setField(-2, "wait");

        l.pushFunction(lKill, "kill");
        l.setField(-2, "kill");

        l.pushFunction(lTerm, "term");
        l.setField(-2, "term");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("@cart/process.Child");
        return 1;
    }

    pub fn push(l: *luau.Luau, child: std.process.Child) *LChild {
        const lchild: *LChild = l.newUserdataDtor(LChild, deinit);
        _ = l.getMetatableRegistry(PROCESS_CHILD_METATABLE);
        l.setMetatable(-2);
        lchild.child = child;
        lchild.term = null;
        return lchild;
    }

    pub fn deinit(self: *LChild) void {
        if (self.child) |c| {
            self.child = null;
            var copy = c;
            _ = copy.wait() catch {};
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
        const self: *LChild = l.checkUserdata(LChild, 1, PROCESS_CHILD_METATABLE);
        if (self.child) |*c| {
            self.term = try c.wait();
            pushTerm(l, self.term.?);
            self.child = null;
            return 1;
        } else {
            l.argError(1, "child already closed");
        }
        return 0;
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
};

pub fn pushTerm(l: *luau.Luau, term: std.process.Child.Term) void {
    l.newTable();

    switch (term) {
        inline else => |code, tag| {
            l.pushString(@tagName(tag));
            l.setField(-2, "type");
            l.pushInteger(@intCast(code));
            l.setField(-2, "code");
        },
    }
}

pub fn open(l: *luau.Luau) void {
    LChild.open(l);

    l.newTable();

    l.pushString("argv");
    l.pushFunction(lArgv, "@cart/process.argv");
    l.setTable(-3);

    l.pushString("getenv");
    l.pushFunction(lGetenv, "@cart/process.getenv");
    l.setTable(-3);

    l.pushString("exit");
    l.pushFunction(lExit, "@cart/process.exit");
    l.setTable(-3);

    l.pushString("spawn");
    l.pushFunction(lSpawn, "@cart/process.spawn");
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
        .none => {},
        else => {
            l.argError(2, "expected table or no argument");
        },
    }

    var c = std.process.Child.init(args.items, lallocator);
    try c.spawn();
    _ = LChild.push(l, c);
    return 1;
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
