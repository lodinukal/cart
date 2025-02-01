--!strict
local io = require("io")
local result = require("result")

local fs = {}

export type ErrorKind =
	"FileNotFound"
	| "PathAlreadyExists"
	| "AccessDenied"
	| "SharingViolation"
	| "OutOfMemory"
	| "Unknown"
fs.error = (nil :: any) :: result.Error<{
	kind: ErrorKind,
	path: string,
}>

export type Permissions = {
	read: boolean,
	write: boolean,
	execute: boolean,
}
export type PermissionGroup = "user" | "group" | "other"

export type OpenMode = "read_only" | "write_only" | "read_write"
export type Lock = "none" | "shared" | "exclusive"

export type OpenFlags = {
	open_mode: OpenMode?,
	lock: Lock?,
	create_if_not_exists: boolean?,
}

export type CreateFlags = {
	open_mode: OpenMode?,
	lock: Lock?,
	exclusive: boolean?,
	truncate_if_exists: boolean?,
}

export type File = {
	close: (self: File) -> (),

	get_readonly: (self: File) -> boolean,
	set_readonly: (self: File, readonly: boolean) -> (),

	--- Returns the permissions for the given file
	--- @param file The file to get the permissions for
	--- @param group The group to get the permissions for, ignored on non-POSIX systems
	get_permissions: (self: File, group: PermissionGroup) -> Permissions,

	--- Sets the permissions for the given file
	--- @param file The file to set the permissions for
	--- @param permissions The permissions to set
	--- @param group The group to set the permissions for, ignored on non-POSIX systems
	set_permissions: (self: File, permissions: Permissions, group: PermissionGroup) -> (),

	reader: (self: File) -> io.Reader,
	writer: (self: File) -> io.Writer,
}

function fs.create_file(path: string, flags: CreateFlags): File
	local _ = path
	local _ = flags
	return nil :: any
end

function fs.open_file(path: string, flags: OpenFlags): File
	local _ = path
	local _ = flags
	return nil :: any
end

function fs.delete_file(path: string): boolean
	local _ = path
	return nil :: any
end

function fs.exists(path: string): boolean
	local _ = path
	return nil :: any
end

return fs
