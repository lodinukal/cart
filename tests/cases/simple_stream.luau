local result = require("@cart/result")
local stream = require("@cart/stream")

export type FixedStream = {
	pointer: number,
}

export type FixedStreamReader = FixedStream & stream.Reader<FixedStream>
export type FixedStreamWriter = FixedStream & stream.Writer<FixedStream>

local function fixedstream(backing: buffer, writer: boolean): FixedStream
	return {
		pointer = 0,
		read = function(self: FixedStream, into: buffer): result.Result<number, stream.Error>
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
		write = function(self: FixedStream, from: buffer): result.Result<number, stream.Error>
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
	}
end

local function newreader(backing: buffer): FixedStreamReader
	return fixedstream(backing, false) :: FixedStreamReader
end

local function newwriter(backing: buffer): FixedStreamWriter
	return fixedstream(backing, true) :: FixedStreamWriter
end

local _ = newwriter
local _ = stream

local hello_stream = newreader(buffer.fromstring("Hello, world!"))
local smol_buffer = buffer.create(5)
local read_count = hello_stream:read(smol_buffer)
assert(read_count.ok, "Failed to read from stream")
assert(read_count.value == 5, "Read count mismatch")
assert(buffer.tostring(smol_buffer) == "Hello", "Buffer content mismatch")

-- reset before handing to zig
hello_stream.pointer = 0
return hello_stream
