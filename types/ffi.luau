--!strict
local ffi = {}

-- Note, any structures with missing keys will be assumed to have zeroed out values

export type Structure = {}

export type CType =
	"void"
	| "complex_double"
	| "complex_float"
	| "complex_long_double"
	| "double"
	| "float"
	| "long"
	| "long_double"
	| "pointer"
	| "schar"
	| "sint"
	| "sint16"
	| "sint32"
	| "sint64"
	| "sint8"
	| "uchar"
	| "uint"
	| "uint16"
	| "uint32"
	| "uint64"
	| "uint8"
	| "ulong"
	| "ushort"
	| "bool8"
	| Structure

export type Dynlib = {
	--- Search for a function in a dynamic library.
	--- @param name string the name of the function
	--- @param ret CType the return type of the function
	--- @param ...CType the arguments of the function
	get: <T>(self: Dynlib, name: string, ret: CType, ...CType) -> T?,
	--- Closes a dynamic library.
	close: (self: Dynlib) -> (),
}

--- Opens a dynamic library.
--- @param path string
function ffi.open(path: string): Dynlib?
	local _ = path
	return nil
end

--- Creates a structure type.
--- @param name string the name of the structure
--- @param fields a map of field names to their types, C type layout
--- note the structure created by this cannot be destroyed, it exists for the duration of the program
--- after its been created
function ffi.structure<T>(name: string, fields: { { name: string, ty: CType } }): Structure & T
	local _ = name
	local _ = fields
	return nil :: any
end

return ffi
