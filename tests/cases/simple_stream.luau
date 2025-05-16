type FixedStream = {
	pointer: number,
} & Seekable<FixedStream, FixedStreamError>

export type FixedStreamReader = FixedStream & Reader<FixedStream, FixedStreamError>
export type FixedStreamWriter = FixedStream & Writer<FixedStream, FixedStreamError>

export type FixedStreamError =
	| "OutOfBounds"
	| "InvalidReader"
	| "InvalidWriter"
	| "InvalidState"
	| "InvalidArgument"
	| "NotImplemented"
	| "NotAFile"
	| "InvalidFile"
	| "FileNotFound"
	| "PathAlreadyExists"
	| "AccessDenied"

local function fixedstream(backing: buffer, writer: boolean): FixedStream
	return {
		pointer = 0,
		read = function(self: FixedStream, into: buffer): Result<number, FixedStreamError>
			if writer then
				return {
					ok = false,
					why = "InvalidReader",
					explanation = "Cannot read from a writer",
				}
			end
			local len = buffer.len(into)
			buffer.copy(into, 0, backing, self.pointer, len)
			self.pointer += len
			return {
				ok = true,
				value = len,
			}
		end,
		write = function(self: FixedStream, from: buffer): Result<number, FixedStreamError>
			if not writer then
				return {
					ok = false,
					why = "InvalidReader",
					explanation = "Cannot write to a reader",
				}
			end
			local len = buffer.len(from)
			buffer.copy(backing, self.pointer, from, 0, len)
			self.pointer += len
			return {
				ok = true,
				value = len,
			}
		end,
		seek = function(self: FixedStream, offset: number): Result<nil, FixedStreamError>
			if offset < 0 or offset > buffer.len(backing) then
				return {
					ok = false,
					why = "OutOfBounds",
					explanation = "Offset out of bounds",
				} :: Result<nil, FixedStreamError>
			end
			self.pointer = offset
			return {
				ok = true,
				value = nil,
			}
		end,
		tell = function(self: FixedStream): Result<number, FixedStreamError>
			return {
				ok = true,
				value = self.pointer,
			}
		end,
	}
end

local function newreader(backing: buffer): FixedStreamReader
	return fixedstream(backing, false) :: FixedStreamReader
end

local function newwriter(backing: buffer): FixedStreamWriter
	return fixedstream(backing, true) :: FixedStreamWriter
end

local _ = newwriter

local hello_stream = newreader(buffer.fromstring("Hello, world!"))
local smol_buffer = buffer.create(5)
local read_count = hello_stream:read(smol_buffer)
assert(read_count.ok, "Failed to read from stream")
assert(read_count.value == 5, "Read count mismatch")
assert(buffer.tostring(smol_buffer) == "Hello", "Buffer content mismatch")

hello_stream:seek(0)
return hello_stream
