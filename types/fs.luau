--!strict
local io = require("io")

local fs = {}

export type Permissions = {
	read: boolean,
	write: boolean,
	execute: boolean,
}
export type PermissionGroup = "user" | "group" | "other"

export type OpenMode = "read_only" | "write_only" | "read_write"
export type Lock = "none" | "shared" | "exclusive"

export type FileFlags = {
	open_mode: OpenMode?,
	lock: Lock?,
	create_if_not_exists: boolean?,
	truncate_if_exists: boolean?,
}

export type File = {
	close: (self: File) -> (),

	getReadonly: (self: File) -> boolean,
	setReadonly: (self: File, readonly: boolean) -> (),

	--- Returns the permissions for the given file
	--- @param file The file to get the permissions for
	--- @param group The group to get the permissions for, ignored on non-POSIX systems
	getPermissions: (self: File, group: PermissionGroup) -> Permissions,

	--- Sets the permissions for the given file
	--- @param file The file to set the permissions for
	--- @param permissions The permissions to set
	--- @param group The group to set the permissions for, ignored on non-POSIX systems
	setPermissions: (self: File, permissions: Permissions, group: PermissionGroup) -> (),

	reader: (self: File) -> io.Reader,
	writer: (self: File) -> io.Writer,
}

function fs.openFile(path: string, flags: FileFlags): File
	local _ = path
	local _ = flags
	return nil :: any
end

function fs.deleteFile(path: string): boolean
	local _ = path
	return nil :: any
end

function fs.exists(path: string): boolean
	local _ = path
	return nil :: any
end

return fs
