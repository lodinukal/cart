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

const std = @import("std");
const luau = @import("luau");
