const SYMBOL_METATABLE = "@cart/ffi.Symbol";
const DYNLIB_METATABLE = "@cart/ffi.Dynlib";
const STRUCTURE_METATABLE = "@cart/ffi.Structure";

const MAX_ARGS = 8;
const MAX_FIELDS = 16;
const MARSHAL_TEMP_SIZE = 1024;

pub fn open(l: *luau.Luau) void {
    LDynLib.open(l);
    LSymbol.open(l);
    LStructure.open(l);

    l.newTable();

    l.pushString("open");
    l.pushFunction(lOpen, "@cart/ffi.open");
    l.setTable(-3);

    l.pushString("structure");
    l.pushFunction(lStructure, "@cart/ffi.structure");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

const CPrimitiveType = enum(u32) {
    void,
    double,
    float,
    long,
    long_double,
    pointer,
    schar,
    sint,
    sint16,
    sint32,
    sint64,
    sint8,
    uchar,
    uint,
    uint16,
    uint32,
    uint64,
    uint8,
    ulong,
    ushort,
    bool8,

    pub fn ZigType(comptime ty: CPrimitiveType) type {
        return switch (ty) {
            .void => void,
            .double => f64,
            .float => f32,
            .long => c_long,
            .long_double => c_longdouble,
            .pointer => [*]u8,
            .schar => i8,
            .sint => c_int,
            .sint16 => i16,
            .sint32 => i32,
            .sint64 => i64,
            .sint8 => i8,
            .uchar => u8,
            .uint => c_uint,
            .uint16 => u16,
            .uint32 => u32,
            .uint64 => u64,
            .uint8 => u8,
            .ulong => c_long,
            .ushort => c_ushort,
            .bool8 => u8,
        };
    }

    pub inline fn asType(ty: CPrimitiveType) *ffi.Type {
        switch (ty) {
            inline .bool8 => return ffi.types.uint8,
            inline else => |e| {
                return @field(ffi.types, @tagName(e));
            },
        }
    }

    pub fn coerceLuauType(ty: CPrimitiveType, l: *luau.Luau, index: i32, allocator: std.mem.Allocator) !*anyopaque {
        switch (ty) {
            inline .ulong,
            .ushort,
            .long,
            .schar,
            .sint,
            .sint16,
            .sint32,
            .sint64,
            .sint8,
            .uchar,
            .uint,
            .uint16,
            .uint32,
            .uint64,
            .uint8,
            => |t| {
                const T = comptime t.ZigType();
                const n = try l.toNumber(index);
                const ptr = try allocator.create(T);
                ptr.* = @intFromFloat(n);
                return @ptrCast(ptr);
            },
            inline .double,
            .long_double,
            .float,
            => |t| {
                const T = comptime t.ZigType();
                const n = try l.toNumber(index);
                const ptr = try allocator.create(T);
                ptr.* = @floatCast(n);
                return @ptrCast(ptr);
            },
            .pointer => {
                switch (l.typeOf(index)) {
                    .string => {
                        const string = try l.toString(index);
                        const ptr = try allocator.create([*]u8);
                        ptr.* = @constCast(@ptrCast(string.ptr));
                        return @ptrCast(ptr);
                    },
                    .buffer => {
                        const buffer = try l.toBuffer(index);
                        const ptr = try allocator.create([*]u8);
                        ptr.* = buffer.ptr;
                        return @ptrCast(ptr);
                    },
                    else => return error.UnexpectedTypeToPointer,
                }
            },
            .void => {
                return @ptrCast(try allocator.create(void));
            },
            .bool8 => {
                const b = l.toBoolean(index);
                const ptr = try allocator.create(u8);
                ptr.* = if (b) 1 else 0;
                return @ptrCast(ptr);
            },
        }
    }
};

const LStructure = struct {
    l: *luau.Luau,
    arena: std.heap.ArenaAllocator,
    type_: ffi.Type = undefined,
    type_name: [:0]const u8,
    fields_raw: std.BoundedArray(?*ffi.Type, MAX_FIELDS) = .{},
    fields_names: std.BoundedArray([:0]const u8, MAX_FIELDS) = .{},
    fields_ctypes: std.BoundedArray(CType, MAX_FIELDS) = .{},

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(STRUCTURE_METATABLE) catch @panic("failed to create structure metatable");
        l.pushString(STRUCTURE_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");
    }

    pub fn lToString(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LStructure, 1) catch l.argError(1, "expected structure");
        try l.pushFmtString("cart.Structure<{s}>", .{self.type_name});
        return 1;
    }

    pub fn push(l: *luau.Luau) *LStructure {
        const self = l.newUserdataDtor(LStructure, deinit);
        _ = l.getMetatableRegistry(STRUCTURE_METATABLE);
        l.setMetatable(-2);
        return self;
    }

    pub fn deinit(self: *LStructure) void {
        self.arena.deinit();
    }
};

const CType = union(enum) {
    primitive: CPrimitiveType,
    structure: *LStructure,

    pub fn asType(self: *CType) *ffi.Type {
        return switch (self.*) {
            .primitive => self.primitive.asType(),
            .structure => &self.structure.type_,
        };
    }

    pub fn coerceLuauType(self: CType, l: *luau.Luau, index: i32, allocator: std.mem.Allocator) !*anyopaque {
        return switch (self) {
            .primitive => CPrimitiveType.coerceLuauType(self.primitive, l, index, allocator),
            .structure => {
                l.pushValue(index);
                l.pushNil();
                const buffer = try allocator.alloc(u8, self.structure.type_.size);
                var offsets: [MAX_FIELDS]usize = undefined;
                if (ffi.ffi_get_struct_offsets(switch (@import("builtin").target.os.tag) {
                    .windows => .win64,
                    else => .sysv64,
                }, &self.structure.type_, &offsets) != .ok) {
                    l.raiseErrorFmt("failed to get struct offsets", .{}) catch unreachable;
                }
                while (l.next(-2)) {
                    l.pushValue(-2);
                    const key = try l.toString(-1);
                    const index_of_field: usize = blk: {
                        for (self.structure.fields_names.constSlice(), 0..) |field, field_index| {
                            if (std.mem.eql(u8, key, field)) {
                                break :blk field_index;
                            }
                        }
                        l.pop(2);
                        l.raiseErrorFmt("field not found: {s}", .{key}) catch unreachable;
                    };
                    const field = self.structure.fields_ctypes.buffer[index_of_field];
                    var structure_field_buffer = std.heap.FixedBufferAllocator.init(buffer[offsets[index_of_field]..]);
                    const structure_field_allocator = structure_field_buffer.allocator();
                    _ = try field.coerceLuauType(l, -2, structure_field_allocator);
                    l.pop(2);
                }
                l.pop(1);
                return @ptrCast(buffer.ptr);
            },
        };
    }

    pub fn pushLuauType(self: CType, l: *luau.Luau, result: ffi.uarg) !i32 {
        switch (self) {
            .primitive => |primitive| switch (primitive) {
                .ulong,
                .ushort,
                .long,
                .schar,
                .sint,
                .sint16,
                .sint32,
                .sint64,
                .sint8,
                .uchar,
                .uint,
                .uint16,
                .uint32,
                .uint64,
                .uint8,
                .double,
                .long_double,
                .float,
                => {
                    l.pushNumber(@floatFromInt(result));
                    return 1;
                },
                .pointer => {
                    l.pushLightUserdata(@ptrFromInt(result));
                    return 1;
                },
                .void => {
                    return 0;
                },
                .bool8 => {
                    l.pushBoolean(result != 0);
                    return 1;
                },
            },
            .structure => {
                // l.pushString("structure");
                return 0;
            },
        }
    }

    pub fn getSize(self: CType) usize {
        return switch (self) {
            .primitive => switch (self.primitive) {
                .ulong => @sizeOf(c_ulong),
                .ushort => @sizeOf(c_ushort),
                .long => @sizeOf(c_long),
                .schar => @sizeOf(i8),
                .sint => @sizeOf(c_int),
                .sint16 => @sizeOf(i16),
                .sint32 => @sizeOf(i32),
                .sint64 => @sizeOf(i64),
                .sint8 => @sizeOf(i8),
                .uchar => @sizeOf(u8),
                .uint => @sizeOf(c_uint),
                .uint16 => @sizeOf(u16),
                .uint32 => @sizeOf(u32),
                .uint64 => @sizeOf(u64),
                .uint8 => @sizeOf(u8),
                .double => @sizeOf(f64),
                .long_double => @sizeOf(c_longdouble),
                .float => @sizeOf(f32),
                .pointer => @sizeOf([*]u8),
                .void => 0,
                .bool8 => @sizeOf(u8),
            },
            .structure => |structure| {
                var total: usize = 0;
                for (structure.fields_raw.constSlice()) |field| {
                    total += (field orelse break).size;
                }
                return total;
            },
        };
    }
};

const LSymbol = struct {
    l: *luau.Luau,
    lib_ref: ?i32,

    symbol: *const anyopaque,

    args: std.BoundedArray(*ffi.Type, MAX_ARGS) = .{},
    return_type: *ffi.Type = ffi.types.void,

    args_enum: std.BoundedArray(CType, MAX_ARGS) = .{},
    return_type_enum: CType = .{ .primitive = .void },

    func: ffi.Function = undefined,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(SYMBOL_METATABLE) catch @panic("failed to create symbol metatable");
        l.pushString(SYMBOL_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushFunction(lCall, "__call");
        l.setField(-2, "__call");
        l.pushValue(-1);
        l.setField(-2, "__index");
    }

    pub fn lToString(l: *luau.Luau) !i32 {
        l.pushFmtString("cart.Symbol<{x}>", .{@intFromPtr(l)}) catch l.pushString("cart.Symbol<?>");
        return 1;
    }

    fn lCall(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LSymbol, 1) catch l.argError(1, "expected symbol");
        const arg_count: usize = @intCast(l.getTop() - 1);

        var buf = std.mem.zeroes([MARSHAL_TEMP_SIZE]u8);
        var fba = std.heap.FixedBufferAllocator.init(buf[0..]);
        if (arg_count != self.args.len) {
            l.argError(1, try std.fmt.allocPrintZ(
                fba.allocator(),
                "expected {d} arguments, got {d}",
                .{ self.args.len, arg_count },
            ));
        }

        fba.end_index = 0;
        const temp_allocator = fba.allocator();

        var args: [MAX_ARGS]*anyopaque = undefined;
        for (1..@as(usize, @intCast(arg_count + 1)), 0..) |i, at| {
            const i_as_i32: i32 = @intCast(i + 1);
            const arg = try self.args_enum.buffer[at].coerceLuauType(l, i_as_i32, temp_allocator);
            args[at] = arg;
        }

        var result: ffi.uarg = undefined;
        self.func.call(@as(*const fn () void, @ptrCast(self.symbol)), &args, &result);

        return self.return_type_enum.pushLuauType(l, result);
    }

    pub fn push(l: *luau.Luau, ref_lib: i32, symbol: *const anyopaque) !*LSymbol {
        // luau will not mutate the pointer
        const lib_ref = try l.ref(ref_lib);
        const self = l.newUserdataDtor(LSymbol, deinit);
        self.* = .{
            .l = l,
            .lib_ref = lib_ref,
            .symbol = symbol,
        };
        _ = l.getMetatableRegistry(SYMBOL_METATABLE);
        l.setMetatable(-2);
        return @ptrCast(self);
    }

    fn deinit(self: *LSymbol) void {
        if (self.lib_ref) |ref| {
            self.l.unref(ref);
            self.lib_ref = null;
        }
    }
};

const LDynLib = struct {
    dynlib: ?std.DynLib = null,

    pub fn open(l: *luau.Luau) void {
        l.newMetatable(DYNLIB_METATABLE) catch @panic("failed to create dynlib metatable");
        l.pushString(DYNLIB_METATABLE);
        l.setField(-2, "__type");
        l.pushString("This metatable is locked");
        l.setField(-2, "__metatable");
        l.pushFunction(lToString, "__tostring");
        l.setField(-2, "__tostring");
        l.pushValue(-1);
        l.setField(-2, "__index");

        l.pushFunction(lClose, "close");
        l.setField(-2, "close");

        l.pushFunction(lGet, "get");
        l.setField(-2, "get");
    }

    fn lToString(l: *luau.Luau) !i32 {
        l.pushString("cart.DynLib");
        return 1;
    }

    pub fn push(l: *luau.Luau, lib: std.DynLib) *LDynLib {
        const self = l.newUserdataDtor(LDynLib, deinit);
        self.dynlib = lib;
        _ = l.getMetatableRegistry(DYNLIB_METATABLE);
        l.setMetatable(-2);
        return self;
    }

    pub fn deinit(self: *LDynLib) void {
        if (self.dynlib) |*dynlib| dynlib.close();
        self.dynlib = null;
    }

    pub fn lClose(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LDynLib, 1) catch l.argError(1, "expected dynlib");
        if (self.dynlib) |_| {
            self.deinit();
        } else {
            l.raiseErrorFmt("dynlib already closed", .{}) catch unreachable;
        }
        return 0;
    }

    pub fn lGet(l: *luau.Luau) !i32 {
        const self = l.toUserdata(LDynLib, 1) catch l.argError(1, "expected dynlib");
        const symbol = l.toString(2) catch l.argError(2, "expected name of symbol");

        const dynlib = &(self.dynlib orelse (l.raiseErrorFmt("dynlib already closed", .{}) catch unreachable));
        const sym = if (dynlib.lookup(*const anyopaque, symbol)) |found|
            try LSymbol.push(l, 1, found)
        else {
            l.pushNil();
            return 1;
        };

        const top = l.getTop();
        const bottom = 3;
        const number_total = top - bottom;
        if (number_total > MAX_ARGS) {
            l.argError(3, "too many arguments");
        }

        // first argument is the return type
        sym.return_type_enum = parseType(l, 3) catch l.argError(3, "expected return type");
        sym.return_type = sym.return_type_enum.asType();

        for (1..@as(usize, @intCast(number_total)), 0..) |i, at| {
            const i_as_i32: i32 = @intCast(i);
            const ty = parseType(l, bottom + i_as_i32) catch
                l.argError(bottom + i_as_i32, "expected type");
            sym.args_enum.appendAssumeCapacity(ty);
            sym.args.appendAssumeCapacity(sym.args_enum.buffer[at].asType());
        }

        std.log.info("return: {}", .{sym.return_type});
        for (sym.args.constSlice()) |arg| {
            std.log.info("arg: {}", .{arg});
        }

        try sym.func.prepare(.default, @intCast(sym.args.len), sym.args.slice().ptr, sym.return_type);

        return 1;
    }
};

// 1: string dynlib name
fn lOpen(l: *luau.Luau) !i32 {
    const name = l.toString(1) catch l.argError(1, "expected dynlib name");
    switch (@import("builtin").os.tag) {
        .windows, .macos, .linux, .ios => {
            const lib = std.DynLib.open(name) catch {
                l.pushNil();
                return 1;
            };
            _ = LDynLib.push(l, lib);
        },
        else => {
            l.pushString("dynlib not supported on this platform");
            return l.raiseError();
        },
    }
    return 1;
}

// 1: string type name
// 2: {{name: string, ty: CType}}
fn lStructure(l: *luau.Luau) !i32 {
    const type_name = l.toString(1) catch l.argError(1, "expected type name");

    if (l.typeOf(2) != .table) {
        l.argError(2, "expected table");
    }
    const len = l.objLen(2);
    if (len == 0) {
        l.argError(2, "expected at least one field");
    }
    if (len > MAX_FIELDS) {
        l.argError(2, "too many fields");
    }

    const structure = LStructure.push(l);
    structure.* = .{
        .l = l,
        .arena = std.heap.ArenaAllocator.init(l.allocator()),
        .type_name = try structure.arena.allocator().dupeZ(u8, type_name),
    };
    structure.type_.elements = @ptrCast(structure.fields_raw.slice().ptr);

    l.pushValue(2);
    for (0..@as(usize, @intCast(len))) |index| {
        const actual_index: i32 = @intCast(index + 1);
        l.pushInteger(actual_index);
        if (l.getTable(-2) == .nil) break;
        const name = try l.getFieldObjConsumed(-1, "name");
        if (name != .string) {
            l.argError(1, "expected string for field name");
        }
        _ = try l.getFieldObj(-1, "ty");
        const ty = parseType(l, -1) catch l.argError(-1, "expected type");
        l.pop(1);
        structure.fields_names.appendAssumeCapacity(try structure.arena.allocator().dupeZ(u8, name.string));
        structure.fields_ctypes.appendAssumeCapacity(ty);
        structure.fields_raw.appendAssumeCapacity(
            structure.fields_ctypes.buffer[structure.fields_ctypes.len - 1].asType(),
        );
        l.pop(1);
    }
    l.pop(1);
    structure.fields_raw.appendAssumeCapacity(null);

    const temp_type: CType = .{ .structure = structure };
    structure.type_.alignment = 8;
    structure.type_.id = .@"struct";
    structure.type_.size = temp_type.getSize();

    return 1;
}

pub fn parseType(l: *luau.Luau, index: i32) !CType {
    switch (l.typeOf(index)) {
        .string => {
            const ty = util.parseStringAsEnum(CPrimitiveType, l, index, null) catch return error.InvalidPrimitiveType;
            return .{ .primitive = ty };
        },
        .userdata => {
            const structure = l.toUserdata(LStructure, index) catch return error.InvalidStructureType;
            return .{ .structure = structure };
        },
        else => return error.UnexpectedType,
    }
}

const std = @import("std");
const luau = @import("luau");

const Context = @import("../Context.zig");
const Scheduler = @import("../Scheduler.zig");

const ffi = @import("ffi");
const util = @import("../util.zig");
