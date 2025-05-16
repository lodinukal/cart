-- results
export type Result<T, E> = | { read ok: true, read value: T } | { read ok: false, read why: E, read explanation: string? }

-- streams
export type Reader<T, Err> = {
	--- tries to read buffer.len(into) bytes from the stream into the buffer and returns the number of bytes read or an error message
	read: (self: T, into: buffer) -> Result<number, Err>,
}

export type Writer<T, Err> = {
	--- tries to write buffer.len(from) bytes from the buffer into the stream and returns the number of bytes written or an error message
	write: (self: T, from: buffer) -> Result<number, Err>,
}

export type Seekable<T, Err> = {
	--- gets the position of the stream
	tell: (self: T) -> Result<number, Err>,
	--- tries to seek the stream to the given position and returns the new position or an error message
	seek: (self: T, offset: number) -> Result<nil, Err>,
}

-- fs
export type FileError =
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


export type FilePermissions = {
	read: boolean,
	write: boolean,
	execute: boolean,
}
export type FilePermissionGroup = "user" | "group" | "other"

export type FileOpenMode = "readonly" | "writeonly" | "readwrite"
export type FileLock = "none" | "shared" | "exclusive"

export type FileKind = "file" | "directory" | "symlink" | "namedpipe" | "blockdevice" | "characterdevice" | "unixdomainsocket" | "door" | "eventport" | "whiteout"

declare extern type File with
    function close(self): boolean
    function write(self, data: buffer | string): Result<nil, FileError>
    function append(self, data: buffer | string): Result<nil, FileError>
    function read(self, data: buffer): Result<number, FileError>
    function readtoend(self): Result<buffer, FileError>
	function abspath(self): string
    function relpath(self): string
    function tell(self): number
    function seek(self, offset: number): Result<nil, FileError>
    function seekend(self, offset: number): Result<nil, FileError>
    function lock(self, lock: FileLock): Result<nil, FileError>
    function trylock(self, lock: FileLock): Result<boolean, FileError>
    function unlock(self): nil
    function kind(self): FileKind
    function setreadonly(self, readonly: boolean): Result<nil, FileError>
    function isreadonly(self): boolean
end