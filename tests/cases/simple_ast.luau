local ast = require("@cart/ast")

local source = [[print("Hello, world!")
]] .. "print([[123]])"

local result = ast.parse(source)

assert(result.ok, "Parsing should be ok")
assert(result.value, "Parsing should return a value")
assert(result.value.classindex == "statblock", "Parsing should return a statblock")
local statblock: ast.StatBlock = result.value
assert(#statblock.body == 2, `Parsing should return 2 statements, got {#statblock.body}`)

local first_expr_raw = statblock.body[1]
assert(first_expr_raw.classindex == "statexpr", "First statement should be an expression")
local first_expr: ast.StatExpr = first_expr_raw :: ast.StatExpr
assert(first_expr.expr.classindex == "exprcall", "First expression should be a call")
local first_call: ast.ExprCall = first_expr.expr :: ast.ExprCall
assert(#first_call.args == 1, "First call should have 1 argument")
local first_arg_raw = first_call.args[1]
assert(first_arg_raw.classindex == "exprconstantstring", "First argument should be a string")
local first_arg: ast.ExprConstantString = first_arg_raw :: ast.ExprConstantString
assert(first_arg.value == "Hello, world!", "First argument should be 'Hello, world!'")
assert(first_arg.quotestyle == "simple", "First argument should be a simple string")
assert(first_call.self == false, "First call should not be a method call")
assert(first_call.arglocation, "First call should have argument locations")

local second_expr_raw = statblock.body[2]
assert(second_expr_raw.classindex == "statexpr", "Second statement should be an expression")
local second_expr: ast.StatExpr = second_expr_raw :: ast.StatExpr
assert(second_expr.expr.classindex == "exprcall", "Second expression should be a call")
local second_call: ast.ExprCall = second_expr.expr :: ast.ExprCall
assert(#second_call.args == 1, "Second call should have 1 argument")
local second_arg_raw = second_call.args[1]
assert(second_arg_raw.classindex == "exprconstantstring", "Second argument should be a string")
local second_arg: ast.ExprConstantString = second_arg_raw :: ast.ExprConstantString
assert(second_arg.value == "123", "Second argument should be '123'")
assert(second_arg.quotestyle == "raw", "Second argument should be a raw string")
assert(second_call.self == false, "Second call should not be a method call")
assert(second_call.arglocation, "Second call should have argument locations")
