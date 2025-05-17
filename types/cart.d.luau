-- results
export type Result<T, E> = | { read ok: true, read value: T } | { read ok: false, read why: E, read explanation: string? }

-- streams
export type Reader<T, Err> = {
	--- tries to read buffer.len(into) bytes from the stream into the buffer and returns the number of bytes read or an error message
	read: (self: Reader<T, Err>, into: buffer) -> Result<number, Err>,
}

export type Writer<T, Err> = {
	--- tries to write buffer.len(from) bytes from the buffer into the stream and returns the number of bytes written or an error message
	write: (self: Writer<T, Err>, from: buffer, max_bytes: number?) -> Result<number, Err>,
}

export type Seekable<T, Err> = {
	--- gets the position of the stream
	tell: (self: Seekable<T, Err>) -> Result<number, Err>,
	--- tries to seek the stream to the given position and returns the new position or an error message
	seek: (self: Seekable<T, Err>, offset: number) -> Result<nil, Err>,
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
    function write(self, data: buffer | string, max_bytes: number?): Result<nil, FileError>
    function append(self, data: buffer | string, max_bytes: number?): Result<nil, FileError>
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
	function reader(self): Reader<File, FileError> & Seekable<File, FileError>
	function writer(self): Writer<File, FileError> & Seekable<File, FileError>
end

-- net
export type NetError = 
	| "InvalidState"
	| "InvalidArgument"
	| "NotImplemented"
	| "NotAFile"
	| "InvalidFile"
	| "FileNotFound"
	| "PathAlreadyExists"
	| "AccessDenied"

declare extern type Socket with
	function close(self): boolean
	function bind(self, endpoint: string): Result<nil, NetError>
	function settimeouts(self, read: number?, write: number?): Result<nil, NetError>
	--- only supported for udp sockets on IPv4
	function setbroadcast(self, enable: boolean): Result<nil, NetError>
	--- address family must match the socket family
	function connect(self, endpoint: string): Result<nil, NetError>
	--- call :accept() to get another socket which accepts tcp connections
	function listen(self): Result<nil, NetError>
	--- waits until a connection is made and returns a new socket,
	--- need to call :listen() before calling this
	function accept(self): Result<Socket, NetError>
	--- on UDP will send full packet, on TCP will append to the stream
	function send(self, buffer: buffer, length: number?): Result<number, NetError>
	--- nonblocking peek, does not modify the stream
	function peek(self, buffer: buffer): Result<number, NetError>
	--- blocks until data is available
	function receive(self, buffer: buffer): Result<{length: number, sender: string?}, NetError>
	--- like :send() but only for udp sockets, returns the number of bytes sent
	function sendto(self, endpoint: string, buffer: buffer): Result<number, NetError>
	function enableportreuse(self, enable: boolean): Result<nil, NetError>
	function getlocalendpoint(self): Result<string, NetError>
	function getremoteendpoint(self): Result<string, NetError>
	function joinmulticastgroup(self, interface: string, group: string): Result<nil, NetError>
	function reader(self): Reader<Socket, NetError>
	function writer(self): Writer<Socket, NetError>
end