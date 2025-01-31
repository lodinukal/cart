const HANDLE_METATABLE = "@cart/web.Handle";

pub const Handle = enum(u32) { null, _ };

pub const JsType = enum(u32) {
    null,
    string,
    number,
    bigint,
    boolean,
    symbol,
    undefined,
    object,
    function,

    // extra
    uint8array,
    array,
};

pub const LHandle = struct {
    handle: ?Handle,
    owned: bool,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(HANDLE_METATABLE) catch @panic("failed to create handle metatable");
        l.pushString(HANDLE_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lGet, "get");
        l.setField(-2, "get");

        l.pushFunction(lSet, "set");
        l.setField(-2, "set");

        l.pushFunction(lCall, "call");
        l.setField(-2, "call");

        l.pushFunction(lInvoke, "invoke");
        l.setField(-2, "invoke");

        l.pushFunction(lRelease, "release");
        l.setField(-2, "release");

        l.pushFunction(lTypeof, "typeof");
        l.setField(-2, "typeof");

        l.pushFunction(lUnmarshal, "unmarshal");
        l.setField(-2, "unmarshal");
    }

    fn lToString(l: *luau.Luau) !i32 {
        try l.pushFmtString("{s}({?d})", .{ HANDLE_METATABLE, l.checkUserdata(LHandle, 1, HANDLE_METATABLE).handle });
        return 1;
    }

    fn lGet(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const key = try marshal(l, 2);
        defer key.deinit();
        const value = cart_web_get(
            self.handle orelse l.argError(1, "handle already released"),
            key.handle.?,
        );
        _ = try LHandle.push(l, value);
        return 1;
    }

    fn lSet(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const key = try marshal(l, 2);
        defer key.deinit();
        const value = try marshal(l, 3);
        defer value.deinit();
        cart_web_set(
            self.handle orelse l.argError(1, "handle already released"),
            key.handle.?,
            value.handle.?,
        );
        return 0;
    }

    fn lCall(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const args_len = l.getTop() - 1;

        // should have enough space for 16 arguments
        var buf = std.mem.zeroes([512]u8);
        var handles_buf: [16]*LHandle = undefined;

        var args: []align(1) Handle = std.mem.bytesAsSlice(Handle, &buf);
        args = args[0..@as(usize, @intCast(args_len))];

        const handles: []*LHandle = handles_buf[0..args.len];
        for (args, handles, 0..) |*arg, *handle, i| {
            handle.* = try marshal(l, @intCast(i + 2));
            arg.* = handle.*.handle.?;
        }
        defer for (handles) |arg| {
            arg.deinit();
        };

        const result = cart_web_call(
            self.handle orelse l.argError(1, "handle already released"),
            args.ptr,
            args.len,
        );
        _ = try LHandle.push(l, result);
        return 1;
    }

    fn lInvoke(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const args_len = l.getTop() - 2;

        const method_name = l.checkString(2);

        // should have enough space for 16 arguments
        var buf = std.mem.zeroes([512]u8);
        var handles_buf: [16]*LHandle = undefined;

        var args: []align(1) Handle = std.mem.bytesAsSlice(Handle, &buf);
        args = args[0..@as(usize, @intCast(args_len))];

        const handles: []*LHandle = handles_buf[0..args.len];
        for (args, handles, 0..) |*arg, *handle, i| {
            handle.* = try marshal(l, @intCast(i + 3));
            arg.* = handle.*.handle.?;
        }
        defer for (handles) |arg| {
            arg.deinit();
        };

        const result = cart_web_invoke(
            self.handle orelse l.argError(1, "handle already released"),
            method_name.ptr,
            method_name.len,
            args.ptr,
            args.len,
        );
        _ = try LHandle.push(l, result);
        return 1;
    }

    pub fn deinit(self: *LHandle) void {
        if (!self.owned) {
            return;
        }
        if (self.handle) |handle| {
            cart_web_free(handle);
            self.handle = null;
        }
    }

    pub fn push(l: *luau.Luau, handle: Handle) !*LHandle {
        const self = l.newUserdataDtor(LHandle, deinit);
        _ = l.getMetatableRegistry(HANDLE_METATABLE);
        l.setMetatable(-2);
        self.handle = handle;
        self.owned = true;
        return self;
    }

    fn lRelease(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        if (!self.owned) return 0;
        if (self.handle) |_| {
            self.deinit();
        } else {
            l.argError(1, "handle already released");
        }
        return 0;
    }

    fn lTypeof(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const js_type = cart_web_typeof(self.handle orelse l.argError(1, "handle already released"));
        l.pushString(@tagName(js_type));
        return 1;
    }

    fn lUnmarshal(l: *luau.Luau) !i32 {
        const self: *LHandle = l.checkUserdata(LHandle, 1, HANDLE_METATABLE);
        const handle = self.handle orelse l.argError(1, "handle already released");
        return try unmarshal(l, handle);
    }
};

pub fn open(l: *luau.Luau) void {
    if (!Platform.is_wasm) {
        return;
    }

    LHandle.open(l);

    l.newTable();

    l.pushString("marshal");
    l.pushFunction(lMarshal, "@cart/web.marshal");
    l.setTable(-3);

    l.pushString("global");
    l.pushFunction(lGlobal, "@cart/web.global");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

extern fn cart_web_string(ptr: [*]const u8, len: usize) Handle;
extern fn cart_web_as_string(handle: Handle, ptr: *?[*]const u8, len: *usize) bool;
extern fn cart_web_number(n: f64) Handle;
extern fn cart_web_as_number(handle: Handle, n: *f64) bool;
extern fn cart_web_boolean(b: bool) Handle;
extern fn cart_web_as_boolean(handle: Handle, b: *bool) bool;
extern fn cart_web_buffer(ptr: [*]const u8, len: usize) Handle;
extern fn cart_web_as_buffer(handle: Handle, ptr: *?[*]const u8, len: *usize) bool;
extern fn cart_web_object() Handle;
extern fn cart_web_array() Handle;
extern fn cart_web_free(handle: Handle) void;
extern fn cart_web_typeof(handle: Handle) JsType;
extern fn cart_web_get(handle: Handle, key: Handle) Handle;
extern fn cart_web_set(handle: Handle, key: Handle, value: Handle) void;
extern fn cart_web_call(handle: Handle, args_ptr: [*]align(1) const Handle, args_len: usize) Handle;
extern fn cart_web_invoke(
    handle: Handle,
    name_ptr: [*]const u8,
    name_len: usize,
    args_ptr: [*]align(1) const Handle,
    args_len: usize,
) Handle;
extern fn cart_web_global(ptr: [*]const u8, len: usize) Handle;
extern fn cart_web_function(l: usize, f: i32) Handle;

// 1: string
// 2: as object
pub fn marshal(l: *luau.Luau, arg: i32) !*LHandle {
    switch (l.typeOf(arg)) {
        .none => {
            l.argError(arg, "expected value");
        },
        .userdata => {
            // only marshal handles
            const self: *LHandle = l.checkUserdata(LHandle, arg, HANDLE_METATABLE);
            const handle = self.handle orelse l.argError(arg, "handle already released");
            const new = try LHandle.push(l, handle);
            new.owned = false;
            return new;
        },
        .nil => {
            return try LHandle.push(l, .null);
        },
        .string => {
            const s = try l.toString(arg);
            const handle = cart_web_string(s.ptr, s.len);
            return try LHandle.push(l, handle);
        },
        .number => {
            const n = try l.toNumber(arg);
            const handle = cart_web_number(n);
            return try LHandle.push(l, handle);
        },
        .boolean => {
            const b = l.toBoolean(arg);
            const handle = cart_web_boolean(b);
            return try LHandle.push(l, handle);
        },
        .buffer => {
            const b = try l.toBuffer(arg);
            const handle = cart_web_buffer(b.ptr, b.len);
            return try LHandle.push(l, handle);
        },
        .table => {
            const marshal_as_object = l.toBoolean(2);
            const handle = if (marshal_as_object)
                cart_web_object()
            else
                cart_web_array();
            l.pushValue(arg);
            l.pushNil();
            while (l.next(-2)) {
                const key = key: {
                    if (marshal_as_object) {
                        break :key try marshal(l, -2);
                    }
                    const n = try l.toInteger(-2);
                    const key_handle = cart_web_number(@floatFromInt(n - 1));
                    break :key try LHandle.push(l, key_handle);
                };
                defer key.deinit();
                l.pop(1);
                const value = try marshal(l, -1);
                defer value.deinit();
                l.pop(1);
                cart_web_set(handle, key.handle.?, value.handle.?);
                l.pop(1);
            }
            l.pop(1);
            return try LHandle.push(l, handle);
        },
        .function => {
            const ref = try l.ref(-1);
            l.pop(1);
            const handle = cart_web_function(@intFromPtr(l), ref);
            return try LHandle.push(l, handle);
        },
        else => {
            return error.InvalidType;
        },
    }
}

fn lMarshal(l: *luau.Luau) !i32 {
    _ = try marshal(l, 1);
    return 1;
}

fn lGlobal(l: *luau.Luau) !i32 {
    const name = try l.toString(1);
    const handle = cart_web_global(name.ptr, name.len);
    _ = try LHandle.push(l, handle);
    return 1;
}

pub fn unmarshal(l: *luau.Luau, handle: Handle) !i32 {
    const context = Context.getContext(l) orelse return 0;
    const t = context.temp.allocator();
    switch (cart_web_typeof(handle)) {
        .undefined => {
            l.pushNil();
            return 1;
        },
        .null => {
            l.pushNil();
            return 1;
        },
        .string => {
            var len: usize = 0;
            var ptr: ?[*]const u8 = null;
            if (!cart_web_as_string(handle, &ptr, &len)) {
                return error.FailedToUnmarshalString;
            }
            defer if (ptr) |p| std.heap.wasm_allocator.free(p[0..len]);
            const temp = t.dupeZ(u8, if (ptr) |p| p[0..len] else "") catch return error.OutOfMemory;
            defer t.free(temp);
            l.pushString(temp);
            return 1;
        },
        .number => {
            var n: f64 = 0;
            if (!cart_web_as_number(handle, &n)) {
                return error.FailedToUnmarshalNumber;
            }
            l.pushNumber(n);
            return 1;
        },
        .boolean => {
            var b: bool = false;
            if (!cart_web_as_boolean(handle, &b)) {
                return error.FailedToUnmarshalBoolean;
            }
            l.pushBoolean(b);
            return 1;
        },
        .uint8array => {
            var len: usize = 0;
            var ptr: ?[*]const u8 = null;
            if (!cart_web_as_buffer(handle, &ptr, &len)) {
                return error.FailedToUnmarshalBuffer;
            }
            defer if (ptr) |p| std.heap.wasm_allocator.free(p[0..len]);
            l.pushBuffer(if (ptr) |p| p[0..len] else "");
            return 1;
        },
        else => {
            // just push an unowned handle
            const h = try LHandle.push(l, handle);
            h.owned = false;
            return 1;
        },
    }
}

fn callFunction(l: *luau.Luau, ref: i32, args_ptr: [*]const Handle, args_len: usize) callconv(.c) Handle {
    const args = args_ptr[0..args_len];
    if (l.rawGetIndex(luau.REGISTRYINDEX, ref) != .function) {
        std.log.info("expected function {}", .{ref});
        return .null;
        // l.argError(1, "expected function");
    }
    l.pushValue(-1);
    for (args) |arg| {
        const handle = try LHandle.push(l, arg);
        handle.owned = false;
    }
    l.pcall(@intCast(args_len), luau.MULTRET, 0) catch {
        std.log.info("error calling function: {s}", .{l.toString(-1) catch "unknown"});
        return .null;
    };
    return .null;
}

fn destroyFunction(l: *luau.Luau, ref: i32) callconv(.c) void {
    _ = l;
    _ = ref;
    // l.unref(ref);
}

comptime {
    if (Platform.is_wasm) {
        @export(&callFunction, .{ .name = "cart_callFunction" });
        @export(&destroyFunction, .{ .name = "cart_destroyFunction" });
    }
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");
const Platform = @import("../Platform.zig");

const util = @import("../util.zig");
