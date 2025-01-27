pub fn parseStringAsEnum(comptime E: type, l: *luau.Luau, index: i32) ?E {
    const as_string = l.toString(index) catch return null;
    const enum_value: E = std.meta.stringToEnum(E, as_string) orelse
        return null;
    return enum_value;
}

pub fn tostring(l: *luau.Luau, index: i32) ![:0]const u8 {
    _ = l.getGlobal("tostring");
    l.pushValue(index);
    try l.pcall(1, 1, 0);
    const str = l.toString(-1) catch l.typeNameIndex(index);
    l.pop(1);
    return str;
}

const std = @import("std");
const luau = @import("luau");
