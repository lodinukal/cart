--!strict

export type Reader = {
	--- Reads a number of bytes from the buffer.
	--- @param b The buffer to read from.
	--- @returns The number of bytes read.
	read: (self: Reader, b: buffer) -> number,
}

export type Writer = {
	--- Writes a number of bytes to the buffer.
	--- @param b The buffer to write to.
	--- @returns The number of bytes written.
	write: (self: Writer, b: buffer) -> number,
}

local io = {}

-- function io.readerFromBuffer(b: buffer): Reader
-- 	local _ = b
-- 	return nil :: any
-- end

-- function io.writerFromBuffer(b: buffer): Writer
-- 	local _ = b
-- 	return nil :: any
-- end

return io
