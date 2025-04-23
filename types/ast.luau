local ast = {}
local result = require("@cart/result")

export type ErrorKind = | "InvalidArgument" | "ParseError" | "Unexpected"

export type ClassIndex =
	| "unknown"
	| "attr"
	| "generictype"
	| "generictypepack"
	| "exprgroup"
	| "exprconstantnil"
	| "exprconstantbool"
	| "exprconstantnumber"
	| "exprconstantstring"
	| "exprlocal"
	| "exprglobal"
	| "exprvarargs"
	| "exprcall"
	| "exprindexname"
	| "exprindexexpr"
	| "exprfunction"
	| "exprtable"
	| "exprunary"
	| "exprbinary"
	| "exprtypeassertion"
	| "exprifelse"
	| "exprinterpstring"
	| "statblock"
	| "statif"
	| "statwhile"
	| "statrepeat"
	| "statbreak"
	| "statcontinue"
	| "statreturn"
	| "statexpr"
	| "statlocal"
	| "statfor"
	| "statforin"
	| "statassign"
	| "statcompoundassign"
	| "statfunction"
	| "statlocalfunction"
	| "stattypealias"
	| "stattypefunction"
	| "statdeclareglobal"
	| "statdeclarefunction"
	| "statdeclareclass"
	| "typereference"
	| "typetable"
	| "typefunction"
	| "typetypeof"
	| "typeoptional"
	| "typeunion"
	| "typeintersection"
	| "exprerror"
	| "staterror"
	| "typeerror"
	| "typesingletonbool"
	| "typesingletonstring"
	| "typegroup"
	| "typepackexplicit"
	| "typepackvariadic"
	| "typepackgeneric"

export type Position = {
	line: number,
	column: number,
}

export type Location = {
	begin: Position,
	["end"]: Position,
}

export type NodeBase = {
	classindex: ClassIndex,
	location: Location,
}

export type Attr = NodeBase & {
	classindex: "attr",
	kind: string,
}

export type GenericType = NodeBase & {
	classindex: "generictype",
	name: string,
	defaultvalue: NodeBase?,
}

export type ExprBase = NodeBase & {}

export type ExprConstantNil = ExprBase & {
	classindex: "exprconstantnil",
}

export type ExprConstantBool = ExprBase & {
	classindex: "exprconstantbool",
	value: boolean,
}

export type ExprConstantNumber = ExprBase & {
	classindex: "exprconstantnumber",
	value: number,
}

export type ExprConstantString = ExprBase & {
	classindex: "exprconstantstring",
	value: string,
	quotestyle: QuoteStyle,
}
export type QuoteStyle = "simple" | "raw" | "unquoted"

export type ExprGlobal = ExprBase & {
	classindex: "exprglobal",
	name: string,
}

export type ExprCall = ExprBase & {
	classindex: "exprcall",
	func: Expr,
	args: { Node },
	self: boolean,
	arglocation: { Location }?,
}

export type Expr = | ExprConstantNil | ExprConstantBool | ExprConstantNumber | ExprConstantString | ExprGlobal | ExprCall

export type Stat = NodeBase & {
	hassemicolon: boolean,
}

export type StatBlock = Stat & {
	classindex: "statblock",
	body: { Stat },
	hasend: boolean,
}

export type StatExpr = Stat & {
	classindex: "statexpr",
	expr: Expr,
}

export type Unimplemented = NodeBase & {
	note: "unimplemented",
}

export type Node =
	| Attr
	| GenericType
	| ExprConstantNil
	| ExprConstantBool
	| ExprConstantNumber
	| ExprConstantString
	| ExprGlobal
	| ExprCall
	| StatBlock
	| StatExpr
	| Unimplemented

--
function ast.parse(source: string | buffer): result.Result<StatBlock, ErrorKind>
	return {
		ok = true,
		value = (nil :: any) :: StatBlock,
	}
end

return ast
