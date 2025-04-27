--!strict
local result = require("result")

local fs = {}

export type ErrorKind =
	| "InvalidState"
	| "InvalidArgument"
	| "NotImplemented"
	| "NotAFile"
	| "InvalidFile"
	| "FileNotFound"
	| "PathAlreadyExists"
	| "AccessDenied"
	| "SharingViolation"
	| "DiskQuota"
	| "FileTooBig"
	| "InputOutput"
	| "NoSpaceLeft"
	| "DeviceBusy"
	| "BrokenPipe"
	| "SystemResources"
	| "OperationAborted"
	| "NotOpenForWriting"
	| "LockViolation"
	| "WouldBlock"
	| "ConnectionResetByPeer"
	| "ProcessNotFound"
	| "NoDevice"
	| "NameTooLong"
	| "NotDir"
	| "SymLinkLoop"
	| "IsDir"
	| "ProcessFdQuotaExceeded"
	| "SystemFdQuotaExceeded"
	| "BadPathName"
	| "PipeBusy"
	| "InvalidWtf8"
	| "NetworkNotFound"
	| "AntivirusInterference"
	| "InvalidUtf8"
	| "FileLocksNotSupported"
	| "FileBusy"
	| "Unseekable"
	| "Filesystem"
	| "UnrecognizedVolume"
	| "NotSupported"
	| "FileSystem"
	| "ReadOnlyFileSystem"
	| "LinkQuotaExceeded"
	| "ConnectionTimedOut"
	| "NotOpenForReading"
	| "SocketNotConnected"
	| "Canceled"
	| "DirNotEmpty"
	| "NotSameFileSystem"
	| "OutOfMemory"
	| "Unexpected"

export type Permissions = {
	read: boolean,
	write: boolean,
	execute: boolean,
}
export type PermissionGroup = "user" | "group" | "other"

export type OpenMode = "readonly" | "writeonly" | "readwrite"
export type Lock = "none" | "shared" | "exclusive"

export type OpenFlags = {
	openmode: OpenMode?,
	lock: Lock?,
	--- create if the file does not exist
	create: boolean?,
}

export type CreateFlags = {
	mode: OpenMode?,
	lock: Lock?,
	exclusive: boolean?,
	--- truncate the file if it exists
	truncate: boolean?,
}

function fs.openfile(path: string, flags: OpenFlags): result.Result<File, ErrorKind>
	local _ = path
	local _ = flags
	return nil :: any
end

function fs.createfile(path: string, flags: CreateFlags): result.Result<File, ErrorKind>
	local _ = path
	local _ = flags
	return nil :: any
end

--- If the file is already open, it will be closed and the file descriptor will be returned
--- @param file The file to close
--- @return boolean true if the file was closed successfully, false otherwise
function fs.closefile(file: File): boolean
	local _ = file
	return nil :: any
end

--- Makes all the directories in the given path
--- @param path The path to make a directory
--- @return result.Result<nil, ErrorKind>
function fs.makepath(path: string): result.Result<nil, ErrorKind>
	local _ = path
	return nil :: any
end

--- Deletes a directory/file/symlink
--- @param path The path to delete (can be a file, directory, or symlink)
--- @return result.Result<nil, ErrorKind>
function fs.delete(path: string): result.Result<nil, ErrorKind>
	local _ = path
	return nil :: any
end

--- Writes the given data to the file
--- @param file The file to write to
--- @param data The data to write to the file
function fs.writefile(file: File, data: buffer | string): result.Result<nil, ErrorKind>
	local _ = file
	local _ = data
	return nil :: any
end

--- Appends the given data to the file
--- @param file The file to append to
--- @param data The data to append to the file
function fs.appendfile(file: File, data: buffer | string): result.Result<nil, ErrorKind>
	local _ = file
	local _ = data
	return nil :: any
end

--- Reads the given number of bytes from the file; this uses the current file pointer and will not move it
--- @param file The file to read from
--- @param bytes The number of bytes to read from the file
--- @return buffer The data read from the file
function fs.readfile(file: File, bytes: number): result.Result<buffer, ErrorKind>
	local _ = file
	local _ = bytes
	return nil :: any
end

--- Gets the absolute path of the given file
--- @param file The file to get the absolute path for
--- @return string The absolute path of the file
function fs.abspath(file: File): string
	local _ = file
	return nil :: any
end

--- Gets the relative path of the given file (to the current working directory)
--- @param file The file to get the relative path for
--- @return string The relative path of the file
function fs.relpath(file: File): string
	local _ = file
	return nil :: any
end

--- Gets the position of the file pointer in the file
--- @param file The file to get the position for
--- @return number The position of the file pointer in the file
function fs.tell(file: File): number
	local _ = file
	return nil :: any
end

--- Moves the file pointer to the given position in the file
--- @param file The file to seek in
--- @param offset The offset to move the file pointer to
function fs.seek(file: File, offset: number): result.Result<nil, ErrorKind>
	local _ = file
	local _ = offset
	return nil :: any
end

--- Moves the file pointer to the given position in the file, relative to the end of the file
--- @param file The file to seek in
--- @param offset The offset to move the file pointer to, relative to the end of the file
--- @return result.Result<nil, ErrorKind>
function fs.seekend(file: File, offset: number): result.Result<nil, ErrorKind>
	local _ = file
	local _ = offset
	return nil :: any
end

--- Locks the file for exclusive access
--- @param file The file to lock
--- @return boolean true if the file was locked successfully, false otherwise
function fs.lock(file: File, lock: Lock): result.Result<nil, ErrorKind>
	local _ = file
	return nil :: any
end

--- Tries to lock the file for exclusive access
--- @param file The file to lock
--- @return boolean true if the file was locked successfully, false otherwise
function fs.trylock(file: File, lock: Lock): result.Result<boolean, ErrorKind>
	local _ = file
	return nil :: any
end

--- Unlocks the file
--- @param file The file to unlock
function fs.unlock(file: File): nil
	local _ = file
	return nil
end

--- Creates a symbolic link to a file
--- @param file The file to create a symbolic link to
--- @param target The target of the symbolic link
--- @return result.Result<nil, ErrorKind>
function fs.symlinkfile(path: string, target: string): result.Result<nil, ErrorKind>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a symbolic link to a directory
--- @param file The directory to create a symbolic link to
--- @param target The target of the symbolic link
--- @return result.Result<nil, ErrorKind>
function fs.symlinkdir(path: string, target: string): result.Result<nil, ErrorKind>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a hard link to a file
--- @param file The file to create a hard link to
--- @param target The target of the hard link
--- @return result.Result<nil, ErrorKind>
function fs.hardlinkfile(path: string, target: string): result.Result<nil, ErrorKind>
	local _ = path
	local _ = target
	return nil :: any
end

--- Creates a hard link to a directory
--- @param file The directory to create a hard link to
--- @param target The target of the hard link
--- @return result.Result<nil, ErrorKind>
function fs.hardlinkdir(path: string, target: string): result.Result<nil, ErrorKind>
	local _ = path
	local _ = target
	return nil :: any
end

export type Kind =
	| "blockdevice"
	| "characterdevice"
	| "directory"
	| "namedpipe"
	| "symlink"
	| "file"
	| "unixdomainsocket"
	| "whiteout"
	| "door"
	| "eventport"
	| "unknown"

--- Gets the kind of the file (e.g. regular file, directory, etc.)
--- @param file The file to get the kind for
--- @return string The kind of the file
function fs.kind(file: File): Kind
	local _ = file
	return nil :: any
end

--- Gets the kind of the file without opening it
--- @param path The path to the file to get the kind for
--- @return string The kind of the file, or nil if the file does not exist
function fs.kindpath(path: string): Kind?
	local _ = path
	return nil :: any
end

--- Returns if the file is readonly
function fs.isreadonly(file: File): boolean
	local _ = file
	return nil :: any
end

--- Sets the file as readonly
function fs.setreadonly(file: File, readonly: boolean): result.Result<nil, ErrorKind>
	local _ = file
	local _ = readonly
	return nil :: any
end

return fs
