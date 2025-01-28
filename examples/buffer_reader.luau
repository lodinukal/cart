local io = require("@cart/io")

local a_buffer = buffer.fromstring("hello world one two")
local reader = io.reader_from_buffer(a_buffer)

local out_buf = buffer.create(13)
reader:skip(1)
while reader:read(out_buf) > 0 do
	print(buffer.tostring(out_buf))
end
