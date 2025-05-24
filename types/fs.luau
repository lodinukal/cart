--!strict
local fs = {}

export type OpenFlags = {
	openmode: FileOpenMode?,
	lock: FileLock?,
	--- create if the file does not exist
	create: boolean?,
	follow_symlinks: boolean?,
}

function fs.openfile(path: string, flags: OpenFlags): Result<File, FileError>
	local _ = path
	local _ = flags
	return nil :: any
end

export type CreateFlags = {
	mode: FileOpenMode?,
	lock: FileLock?,
	exclusive: boolean?,
	--- truncate the file if it exists
	truncate: boolean?,
}

function fs.createfile(path: string, flags: CreateFlags): Result<File, FileError>
	local _ = path
	local _ = flags
	return nil :: any
end

--- Makes all the directories in the given path
--- @param path The path to make a directory
--- @return Result<nil, ErrorKind>
function fs.makepath(path: string): Result<nil, FileError>
	local _ = path
	return nil :: any
end

--- Deletes a directory/file/symlink
--- @param path The path to delete (can be a file, directory, or symlink)
--- @return Result<nil, ErrorKind>
function fs.delete(path: string): Result<nil, FileError>
	local _ = path
	return nil :: any
end

--- Gets the kind of the file without opening it
--- @param path The path to the file to get the kind for
--- @return string The kind of the file, or nil if the file does not exist
function fs.kindpath(path: string): FileKind?
	local _ = path
	return nil :: any
end

--- Creates a symbolic link to a file
--- @param file The file to create a symbolic link to
--- @param target The target of the symbolic link
--- @return Result<nil, ErrorKind>
function fs.symlinkfile(path: string, target: string): Result<nil, FileError>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a symbolic link to a directory
--- @param file The directory to create a symbolic link to
--- @param target The target of the symbolic link
--- @return Result<nil, ErrorKind>
function fs.symlinkdir(path: string, target: string): Result<nil, FileError>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a hard link to a file
--- @param file The file to create a hard link to
--- @param target The target of the hard link
--- @return Result<nil, ErrorKind>
function fs.hardlinkfile(path: string, target: string): Result<nil, FileError>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a hard link to a directory
--- @param file The directory to create a hard link to
--- @param target The target of the hard link
--- @return Result<nil, ErrorKind>
function fs.hardlinkdir(path: string, target: string): Result<nil, FileError>
	local _ = path
	local _ = target
	return nil :: any
end

function fs.stdin(): File
	return nil :: any
end

function fs.stdout(): File
	return nil :: any
end

function fs.stderr(): File
	return nil :: any
end

return fs
