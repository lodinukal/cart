/// returns a null value when the index is nil
/// returns an error when the value is not a string or can be converted to the enum type
pub fn parseStringAsEnumRaw(comptime E: type, l: *luau.Luau, index: i32) !?E {
    if (l.typeOf(-1) == .nil) return null;
    const as_string = l.toString(index) catch return error.NotAString;
    const enum_value: E = std.meta.stringToEnum(E, as_string) orelse
        return error.InvalidEnumValue;
    return enum_value;
}

/// validates that:
/// - the value is a string
/// - the string can be converted to the enum type
///
/// arg should be > 0 (arg to a function)
pub fn parseStringAsEnum(comptime E: type, l: *luau.Luau, index: i32, default: ?E) !E {
    return (try parseStringAsEnumRaw(E, l, index)) orelse default orelse return error.InvalidEnumValue;
}

pub fn getEnumMessage(comptime E: type) []const u8 {
    const type_info = @typeInfo(E).@"enum";
    var message = "";
    inline for (type_info.fields, 0..) |field, i| {
        message = message ++ field.name;
        if (i + 1 != type_info.fields.len) {
            message = message ++ ", ";
        }
    }
    return std.fmt.comptimePrint(
        \\expected enum {s}, expected one of ({})
    , .{ if (@hasDecl(E, "pretty_name")) E.pretty_name else @typeName(E), message });
}

pub fn tostring(l: *luau.Luau, index: i32) ![:0]const u8 {
    _ = l.getGlobal("tostring");
    l.pushValue(index);
    try l.pcall(1, 1, 0);
    const str = l.toString(-1) catch l.typeNameIndex(index);
    l.pop(1);
    return str;
}

pub fn dumpstack(l: *luau.Luau) void {
    l.checkStack(3) catch unreachable;
    const top = l.getTop();
    const bottom = 1;
    _ = l.getGlobal("tostring");
    var i: i32 = top;
    while (i >= bottom) : (i -= 1) {
        l.pushValue(-1);
        l.pushValue(@intCast(i));
        l.pcall(1, 1, 0) catch unreachable;
        const str = l.toString(-1) catch l.typeNameIndex(@intCast(i));
        std.log.info("{d}: {s}", .{ i, str });
        l.pop(1);
    }
    l.pop(1);
}

pub fn pushFunction(l: *luau.Luau, comptime f: anytype, name: [:0]const u8) void {
    l.pushCFunction(toCFn(f), name);
}

pub const CFn = *const fn (state: ?*luau.LuaState) callconv(.C) c_int;
pub const ZigFnInt = *const fn (state: *luau.Luau) i32;
pub const ZigFnVoid = *const fn (state: *luau.Luau) void;
pub const ZigFnErrorSet = *const fn (state: *luau.Luau) anyerror!i32;

pub fn ZigToCFn(comptime fnType: std.builtin.Type.Fn, comptime f: anytype) CFn {
    const ri = @typeInfo(fnType.return_type orelse @compileError("Fn must return something"));
    switch (ri) {
        .int => |_| {
            _ = @as(ZigFnInt, f);
            return struct {
                fn inner(s: ?*luau.LuaState) callconv(.C) c_int {
                    // this is called by Luau, state should never be null
                    return @call(.always_inline, f, .{@as(*luau.Luau, @ptrCast(s.?))});
                }
            }.inner;
        },
        .void => |_| {
            _ = @as(ZigFnVoid, f);
            return struct {
                fn inner(s: ?*luau.LuaState) callconv(.C) c_int {
                    // this is called by Luau, state should never be null
                    @call(.always_inline, f, .{@as(*luau.Luau, @ptrCast(s.?))});
                    return 0;
                }
            }.inner;
        },
        .error_union => |_| {
            _ = @as(ZigFnErrorSet, f);
            return struct {
                fn inner(s: ?*luau.LuaState) callconv(.C) c_int {
                    // this is called by Luau, state should never be null
                    const state = @as(*luau.Luau, @ptrCast(s.?));
                    if (@call(.always_inline, f, .{state})) |res|
                        return res
                    else |err| switch (@as(anyerror, @errorCast(err))) {
                        error.RaiseLuauError => state.raiseError(),
                        // else => {
                        //     _ = result.LError.push(state, @errorName(err), false);
                        //     state.raiseError();
                        // },
                        else => state.raiseErrorStr("%s", .{@errorName(err).ptr}),
                    }
                }
            }.inner;
        },
        else => @compileError("Unsupported Fn Return type"),
    }
}

pub fn toCFn(comptime f: anytype) CFn {
    const t = @TypeOf(f);
    const ti = @typeInfo(t);
    switch (ti) {
        .@"fn" => |Fn| return ZigToCFn(Fn, f),
        .pointer => |ptr| {
            // *const fn ...
            if (!ptr.is_const)
                @compileError("Pointer must be constant");
            const pi = @typeInfo(ptr.child);
            switch (pi) {
                .@"fn" => |Fn| return ZigToCFn(Fn, f),
                else => @compileError("Pointer must be a pointer to a function"),
            }
        },
        else => @compileError("zig_fn must be a Fn or a Fn Pointer"),
    }
    @compileError("Could not determine zig_fn type");
}

const std = @import("std");
const luau = @import("luau");

const result = @import("./standard/result.zig");
