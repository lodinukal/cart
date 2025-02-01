pub const ERROR_METATABLE = "@cart.Error";
pub const ERROR_INSTANCE_METATABLE = "@cart.ErrorInstance";

pub const LError = struct {
    id: [:0]const u8,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(ERROR_METATABLE) catch @panic("failed to create error metatable");
        l.pushString(ERROR_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        util.pushFunction(l, lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lAs, "as");
        l.setField(-2, "as");

        l.pushFunction(lInit, "init");
        l.setField(-2, "init");
    }

    /// for use for zig created errors
    pub fn push(l: *luau.Luau, id: [:0]const u8) *LError {
        const self = l.newUserdata(LError);
        _ = l.getMetatableRegistry(ERROR_METATABLE);
        l.setMetatable(-2);
        self.id = id;
        return self;
    }

    fn lToString(l: *luau.Luau) !i32 {
        const self = l.checkUserdata(LError, 1, ERROR_METATABLE);
        try l.pushFmtString("@cart.Error<{s}>", .{self.id});
        return 1;
    }

    fn lAs(l: *luau.Luau) !i32 {
        const self = l.checkUserdata(LError, 1, ERROR_METATABLE);

        // check if error instance
        {
            if (l.getMetatable(2) == false) {
                l.pushNil();
                return 1;
            }

            _ = l.getMetatableRegistry(ERROR_INSTANCE_METATABLE);
            if (l.rawEqual(-1, -2) == false) {
                l.pushNil();
                return 1;
            }
        }

        const instance = l.checkUserdata(LErrorInstance, 2, ERROR_INSTANCE_METATABLE);
        if (std.mem.eql(u8, instance.id, self.id)) {
            l.pushValue(2);
            return 1;
        }

        l.pushNil();
        return 1;
    }

    // 1: self
    // 2: a value, just refs
    fn lInit(l: *luau.Luau) !i32 {
        const self = l.checkUserdata(LError, 1, ERROR_METATABLE);
        l.checkAny(2);
        _ = try LErrorInstance.push(l, self.id, 2);
        return 1;
    }
};

pub const LErrorInstance = struct {
    l: *luau.Luau,
    context: *Context,
    id: [:0]const u8,
    ref_value: ?i32 = null,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(ERROR_INSTANCE_METATABLE) catch @panic("failed to create error instance metatable");
        l.pushString(ERROR_INSTANCE_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        util.pushFunction(l, lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lGet, "get");
        l.setField(-2, "get");
    }

    fn lToString(l: *luau.Luau) !i32 {
        const self = l.checkUserdata(LErrorInstance, 1, ERROR_INSTANCE_METATABLE);
        try l.pushFmtString("@cart.ErrorInstance<{s}>", .{self.id});
        return 1;
    }

    fn lGet(l: *luau.Luau) !i32 {
        const self = l.checkUserdata(LErrorInstance, 1, ERROR_INSTANCE_METATABLE);
        if (self.ref_value) |r| {
            _ = self.l.rawGetIndex(luau.REGISTRYINDEX, r);
            self.l.xMove(l, 1);
            return 1;
        }
        l.argError(1, "error instance is not valid");
    }

    pub fn push(l: *luau.Luau, id: [:0]const u8, index: i32) !*LErrorInstance {
        const r = try l.ref(index);
        l.pop(1);
        const self = l.newUserdataDtor(LErrorInstance, deinit);
        _ = l.getMetatableRegistry(ERROR_INSTANCE_METATABLE);
        l.setMetatable(-2);
        self.l = l;
        self.context = Context.getContext(l) orelse return error.NoContext;
        self.id = id;
        self.ref_value = r;
        return self;
    }

    pub fn raise(l: *luau.Luau, id: [:0]const u8, index: i32) !noreturn {
        _ = try LErrorInstance.push(l, id, index);
        l.raiseError();
    }

    pub fn deinit(self: *LErrorInstance) void {
        if (self.context.exiting) return;
        if (self.ref_value) |value| self.l.unref(value);
        self.ref_value = null;
    }
};

pub fn open(l: *luau.Luau) void {
    LError.open(l);
    LErrorInstance.open(l);

    l.newTable();
    l.setReadOnly(-1, true);
}

// fn lAs(l: *luau.Luau) !i32 {
//     _ = l.toUserdata(LError, 1) catch {
//         l.pushNil();
//         return 1;
//     };
//     if (l.getMetatable(1) == false) {
//         l.pushNil();
//         return 1;
//     }
//     _ = l.getMetatableRegistry(ERROR_METATABLE);
//     if (l.rawEqual(-1, -2) == false) {
//         l.pushNil();
//         return 1;
//     }
//     l.pop(2);

//     return 1;
// }

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");

const util = @import("../util.zig");
