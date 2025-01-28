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
	--- @param offset The offset to start writing from.
	--- @param max_bytes The maximum number of bytes to write.
	--- @returns The number of bytes written.
	write: (self: Writer, b: buffer, offset: number?, max_bytes: number?) -> number,
}

local io = {}

-- function io.reader_from_buffer(b: buffer): Reader
-- 	local _ = b
-- 	return nil :: any
-- end

-- function io.writer_from_buffer(b: buffer): Writer
-- 	local _ = b
-- 	return nil :: any
-- end

--- @param from Reader
--- @param to Writer
--- @param between_reads ((number) -> boolean)? Function to call between reads, do not yield, given the number of bytes read, return true to continue, false to stop.
--- @param buffer_size number? The size of the buffer to use, defaults to 4096
--- @return The number of bytes written.
---
--- blocks and is equivalent to the following if yielding is needed:
--- ```luau
--- local buffer = buffer.create(buffer_size or 4096)
--- local written = 0
--- while true do
--- 	local read = from:read(buffer)
--- 	if read == 0 then
--- 		break
--- 	end
--- 	local written_this_time = to:write(buffer, 0, read)
--- 	written += written_this_time
--- 	if not between_reads or not between_reads(written_this_time) then
--- 		break
--- 	end
--- end
--- return written
--- ```
function io.pipe(from: Reader, to: Writer, between_reads: ((written: number) -> boolean)?, buffer_size: number?): number
	local _ = from
	local _ = to
	local _ = between_reads
	local _ = buffer_size
	return 0
end

return io
