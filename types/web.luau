local web = {}

--- a handle to a js owned object
export type Handle = {
	--- releases the js object
	--- if already released then errors
	release: (self: Handle) -> (),
	--- create a new object
	new: (self: Handle, ...Marshallable) -> Handle,
	--- get the type of the object
	typeof: (self: Handle) -> Type,
	--- get a property of the object
	get: (self: Handle, key: Marshallable) -> Handle,
	--- set a property of the object
	set: (self: Handle, key: Marshallable, value: Marshallable) -> (),
	--- call the object as a function
	call: (self: Handle, ...Marshallable) -> Handle,
	--- call a method on the object
	invoke: (self: Handle, name: string, ...Marshallable) -> Handle,
	--- convert the object to a luau value
	unmarshal: (self: Handle) -> Unmarshalled,
}

export type Type = "string" | "number" | "bigint" | "boolean" | "symbol" | "undefined" | "object" | "function"

export type Marshallable =
	number
	| string
	| boolean
	| nil
	| (...Handle) -> ()
	| { Marshallable }
	| { [Marshallable]: Marshallable }
	| Handle
export type Unmarshalled = number | string | boolean | nil | Handle

--- converts a luau value to a js handle
--- @param s the value to convert
--- @param as_object if true and is a table then convert to a js object, if false then convert to a js array
function web.marshal(s: Marshallable, as_object: boolean?): Handle
	local _ = s
	local _ = as_object
	return nil :: any
end

--- access a global js object by name
function web.global(name: string): Handle
	local _ = name
	return nil :: any
end

return web
