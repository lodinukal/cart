pub fn open(context: *cart.Context) !void {
    if (context.isCached("cart/ast")) return;
    const l = context.state;
    l.createPushTable(.{
        .parse = parseHandled,
    }, null);
    l.setReadonly(.at(-1), true);
    try context.putCache("cart/ast", .at(-1));
    l.pop(1);
}

pub const Error = error{
    InvalidState,
    InvalidArgument,
    OutOfMemory,
    ParseError,
};

pub const NodeClassIndex = enum(u8) {
    unknown,
    attr,
    generictype,
    generictypepack,
    exprgroup,
    exprconstantnil,
    exprconstantbool,
    exprconstantnumber,
    exprconstantstring,
    exprlocal,
    exprglobal,
    exprvarargs,
    exprcall,
    exprindexname,
    exprindexexpr,
    exprfunction,
    exprtable,
    exprunary,
    exprbinary,
    exprtypeassertion,
    exprifelse,
    exprinterpstring,
    statblock,
    statif,
    statwhile,
    statrepeat,
    statbreak,
    statcontinue,
    statreturn,
    statexpr,
    statlocal,
    statfor,
    statforin,
    statassign,
    statcompoundassign,
    statfunction,
    statlocalfunction,
    stattypealias,
    stattypefunction,
    statdeclareglobal,
    statdeclarefunction,
    statdeclareclass,
    typereference,
    typetable,
    typefunction,
    typetypeof,
    typeoptional,
    typeunion,
    typeintersection,
    exprerror,
    staterror,
    typeerror,
    typesingletonbool,
    typesingletonstring,
    typegroup,
    typepackexplicit,
    typepackvariadic,
    typepackgeneric,
};

pub const QuoteStyle = enum(u8) {
    simple,
    raw,
    unquoted,
};

/// pushes 1 value to the stack
fn pushNodeSlice(l: *luau.State, table: *luau.ast.NameTable, slice: []const *luau.ast.Node) void {
    l.createTable(@intCast(slice.len), 0);
    for (slice, 1..) |node, i| {
        l.pushInteger(@intCast(i));
        const wrapper: NodeWrapper = .{
            .node = node,
            .table = table,
        };
        l.createPushTable(wrapper, null);
        l.setTable(.at(-3));
    }
}

pub const NodeWrapper = struct {
    node: *luau.ast.Node,
    table: *luau.ast.NameTable,

    pub fn luauPushTable(self: NodeWrapper, l: *luau.State, table: luau.vm.Index, stack_offset: ?i32) void {
        switch (self.node.classIndex) {
            .attr => {
                const as_attr: *luau.ast.Attr = self.node.cast(.attr) orelse unreachable;
                l.pushTable(table, .{
                    .classindex = NodeClassIndex.attr,
                    .location = as_attr.location,
                    .kind = as_attr.kind,
                }, stack_offset);
            },
            .generic_type => {
                const as_generic: *luau.ast.GenericType = self.node.cast(.generic_type) orelse unreachable;

                const default_value: ?NodeWrapper = if (as_generic.defaultValue) |dv| .{
                    .node = dv,
                    .table = self.table,
                } else null;

                l.pushTable(table, .{
                    .classindex = NodeClassIndex.generictype,
                    .location = as_generic.location,
                    .name = @as([:0]const u8, std.mem.span(as_generic.name.value)),
                    .defaultvalue = default_value,
                }, stack_offset);
            },
            // .generic_type_pack,
            // .expr_group,
            // .expr_constant_nil,
            // .expr_constant_bool,
            // .expr_constant_number,
            .expr_constant_string => {
                const as_string: *luau.ast.ExprConstantString = self.node.cast(.expr_constant_string) orelse unreachable;
                l.pushTable(table, .{
                    .classindex = NodeClassIndex.exprconstantstring,
                    .location = as_string.location,
                    .value = @as([]const u8, as_string.value.slice()),
                    .quotestyle = @as(QuoteStyle, @enumFromInt(@intFromEnum(as_string.quoteStyle))),
                }, stack_offset);
            },
            // .expr_local,
            .expr_global => {
                const as_global: *luau.ast.ExprGlobal = self.node.cast(.expr_global) orelse unreachable;
                l.pushTable(table, .{
                    .classindex = NodeClassIndex.exprglobal,
                    .location = as_global.location,
                    .name = @as([:0]const u8, std.mem.span(as_global.name.value)),
                }, stack_offset);
            },
            // .expr_varargs,
            .expr_call => {
                const as_call: *luau.ast.ExprCall = self.node.cast(.expr_call) orelse unreachable;

                const args = as_call.args.slice();
                pushNodeSlice(l, self.table, args);

                // shift because we pushed the table
                l.pushTable(table.shiftIfNegative(-1), .{
                    .classindex = NodeClassIndex.exprcall,
                    .location = as_call.location,
                    .func = NodeWrapper{
                        .node = as_call.func,
                        .table = self.table,
                    },
                    .args = luau.vm.Index.at(-1),
                    .self = as_call.self,
                    .arglocation = as_call.argLocation,
                }, null);
                // then we pop the created args table
                l.pop(1);
            },
            // .expr_index_name,
            // .expr_index_expr,
            // .expr_function,
            // .expr_table,
            // .expr_unary,
            // .expr_binary,
            // .expr_type_assertion,
            // .expr_if_else,
            // .expr_interp_string,
            .stat_block,
            => {
                const as_block: *luau.ast.StatBlock = self.node.cast(.stat_block) orelse unreachable;

                const body = as_block.body.slice();
                pushNodeSlice(l, self.table, body);

                // shift because we pushed the table
                l.pushTable(table.shiftIfNegative(-1), .{
                    .classindex = NodeClassIndex.statblock,
                    .location = as_block.location,
                    .body = luau.vm.Index.at(-1),
                    .hassemicolon = as_block.MAYBE_hasSemicolon,
                    .hasend = as_block.hasEnd,
                }, null);
                // then we pop the created body table
                l.pop(1);
            },
            // .stat_if,
            // .stat_while,
            // .stat_repeat,
            // .stat_break,
            // .stat_continue,
            // .stat_return,
            .stat_expr => {
                const as_expr: *luau.ast.StatExpr = self.node.cast(.stat_expr) orelse unreachable;
                const expr: NodeWrapper = .{
                    .node = as_expr.expr,
                    .table = self.table,
                };
                l.pushTable(table, .{
                    .classindex = NodeClassIndex.statexpr,
                    .location = as_expr.location,
                    .hassemicolon = as_expr.MAYBE_hasSemicolon,
                    .expr = expr,
                }, stack_offset);
            },
            // .stat_local,
            // .stat_for,
            // .stat_for_in,
            // .stat_assign,
            // .stat_compound_assign,
            // .stat_function,
            // .stat_local_function,
            // .stat_type_alias,
            // .stat_type_function,
            // .stat_declare_global,
            // .stat_declare_function,
            // .stat_declare_class,
            // .type_reference,
            // .type_table,
            // .type_function,
            // .type_typeof,
            // .type_optional,
            // .type_union,
            // .type_intersection,
            // .expr_error,
            // .stat_error,
            // .type_error,
            // .type_singleton_bool,
            // .type_singleton_string,
            // .type_group,
            // .type_pack_explicit,
            // .type_pack_variadic,
            // .type_pack_generic,
            // => {},

            else => |kind| {
                l.pushTable(table, .{
                    .classindex = @as(NodeClassIndex, @enumFromInt(@intFromEnum(kind))),
                    .location = self.node.location,
                    .note = @as([]const u8, "unimplemented"),
                }, stack_offset);
            },
        }
    }
};

fn parseHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        parse(l, &diagnostics),
        &diagnostics,
    );
}

// parse the contents at arg 1
fn parse(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) !luau.vm.Index {
    const context: *cart.Context = try .fromState(l);
    _ = context;
    const source: []const u8 = switch (l.type(.at(1))) {
        .string => l.toLengthString(.at(1)),
        .buffer => l.toBuffer(.at(1)).constSlice(),
        else => |got_type| {
            if (diagnostics) |diag| {
                diag.push(
                    "Invalid argument type, expected string or buffer but got {s}",
                    .{l.typeName(got_type)},
                ) catch {};
            }
            return error.InvalidArgument;
        },
    };

    const allocator = l.allocator();
    // luau needs a special allocator (its like an arena)
    const a = luau.Allocator.init(&allocator);
    defer a.deinit();

    var table = luau.ast.NameTable.init(a);
    defer table.deinit();

    const result = cart.luau.ast.parse(source, table, a);

    const errors = try result.getErrors(allocator);
    defer errors.deinit();

    if (errors.values.len > 0) {
        if (diagnostics) |diag| {
            for (errors.values) |err| {
                diag.push("{}:{}:{s}", .{
                    err.location.begin.line,
                    err.location.begin.column,
                    err.message,
                }) catch {};
            }
        }
        return error.ParseError;
    }

    const wrapper: NodeWrapper = .{
        .node = result.getRoot(),
        .table = table,
    };

    l.pushVal(wrapper, 0);
    return .at(-1);
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;
