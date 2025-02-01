--!strict
local ffi = {}

-- Note, any structures with missing keys will be assumed to have zeroed out values

export type Structure<T> = {
	--- Writes a structure to a buffer so that it can be read by C code.
	--- @param b buffer the buffer to write to
	--- @param offset number the offset to write to
	--- @param value T the value to write
	write: (self: Structure<T>, b: buffer, offset: number, value: T) -> (),
}

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
	| Structure<any>

export type BufferSlice = {
	--- Releases a buffer pointer ref (allows the buffer to be gced).
	release: (self: BufferSlice) -> (),
}
export type StructureArg<T> = T | BufferSlice

export type Dynlib = {
	--- Search for a function in a dynamic library.
	--- @param name string the name of the function
	--- @param ret CType the return type of the function
	--- @param ...CType the arguments of the function
	get: <T>(self: Dynlib, name: string, ret: CType, ...CType) -> T?,
	--- Loads a function with a signature like: (l: *LuauState) -> i32, where an error is < 0 and passes the current state.
	--- Like opening a library in normal lua. Only available when luau has been linked dynamically.
	--- This can return anything as given by the resulting function.
	--- @param name the name of the function
	open_lib: <T>(self: Dynlib, name: string) -> T,
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
--- Will not be defined on wasi platform.
--- @param name string the name of the structure
--- @param fields a map of field names to their types, C type layout
--- note the structure created by this cannot be destroyed, it exists for the duration of the program
--- after its been created
function ffi.structure<T>(name: string, fields: { { name: string, ty: CType } }): Structure<T>
	local _ = name
	local _ = fields
	return nil :: any
end

--- Gets the size of a type in bytes.
--- @param ty CType the type to get the size of
--- @return number the size of the type in bytes
function ffi.sizeof(ty: CType): number
	local _ = ty
	return 0
end

--- Creates a slice to a buffer.
--- @param b buffer the buffer to reference
--- @param offset number the offset to reference
--- @param len optional number the length of the reference
function ffi.slice(b: buffer, offset: number, len: number?): BufferSlice
	local _ = b
	local _ = offset
	local _ = len
	return (nil :: any) :: BufferSlice
end

--- Indicates if the FFI is supported on the current platform.
ffi.supported = false :: boolean

return ffi
