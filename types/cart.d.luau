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
	--- will move the file pointer
	function write(self, data: buffer | string, max_bytes: number?): Result<nil, FileError>
	--- will not move the file pointer
	function pwrite(self, offset: number, data: buffer | string, max_bytes: number?): Result<nil, FileError>
	--- will move the file pointer
	function read(self, data: buffer): Result<number, FileError>
	--- will not move the file pointer
	function pread(self, offset: number, data: buffer): Result<number, FileError>
    -- function write(self, data: buffer | string, max_bytes: number?): Result<nil, FileError>
    -- function append(self, data: buffer | string, max_bytes: number?): Result<nil, FileError>
    -- function read(self, data: buffer): Result<number, FileError>
	--- NOTE: this is currently DOES NOT WORK as iocp will not allow synchronous reads through a async file handle
    -- function readtoend(self): Result<buffer, FileError>
	function abspath(self): string
    function relpath(self): string
    function tell(self): number
	--- using a negative offset will seek from the end of the file
    function seek(self, offset: number): Result<nil, FileError>
    -- function seekend(self, offset: number): Result<nil, FileError>
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
	| "AddressFamilyNotSupported"
	| "ProcessFdQuotaExceeded"
	| "SystemResources"
	| "ProtocolNotSupported"
	| "Canceled"
	| "Unexpected"
	| "BrokenPipe"
	| "ConnectionResetByPeer"
	| "OperationAborted"
	| "LockViolation"
	| "AccessDenied"
	| "NotOpenForReading"
	| "EOF"
	| "NetworkSubsystemFailed"
	| "NotOpenForWriting"
	| "OutOfMemory"
	| "Overflow"
	| "InvalidCharacter"
	| "PermissionDenied"
	| "FileNotFound"
	| "NameTooLong"
	| "NotDir"
	| "SymLinkLoop"
	| "SystemFdQuotaExceeded"
	| "NoDevice"
	| "InvalidArgument"
	| "InvalidState"
	| "NotImplemented"
	| "ReadOnlyFileSystem"
	| "NotATCPStream"
	| "InvalidTCPStream"
	| "InvalidIPAddressFormat"
	| "ProtocolFamilyNotAvailable"
	| "SocketTypeNotSupported"
	| "AddressInUse"
	| "FileDescriptorNotASocket"
	| "OperationNotSupported"
	| "AlreadyConnected"
	| "SocketNotBound"
	| "AddressNotAvailable"
	| "AlreadyBound"
	| "InvalidProtocolOption"
	| "TimeoutTooBig"
	| "UnexpectedCharacter"
	| "InvalidFormat"
	| "InvalidPort"

declare extern type TCPStream with
	function close(self): boolean
	function bind(self, address: string, port: number): Result<nil, NetError>
	function settimeouts(self, read: number?, write: number?): Result<nil, NetError>
	--- address family must match the socket family
	function connect(self, address: string, port: number): Result<nil, NetError>
	--- call :accept() to get another socket which accepts tcp connections
	function listen(self, backlog: number): Result<nil, NetError>
	--- waits until a connection is made and returns a new socket,
	--- need to call :listen() before calling this
	function accept(self): Result<TCPStream, NetError>
	--- on UDP will send full packet, on TCP will append to the stream
	function send(self, buffer: buffer, length: number?): Result<number, NetError>
	--- yields until data is available
	function receive(self, buffer: buffer): Result<number, NetError>
	function getlocalendpoint(self): Result<string, NetError>
	function getremoteendpoint(self): Result<string, NetError>
	function reader(self): Reader<TCPStream, NetError>
	function writer(self): Writer<TCPStream, NetError>
end