local io = require("@cart/io")

local a_buffer = buffer.fromstring("one fish two fish red fish blue fish")
-- limited to                       0123^^^^
-- thus should only replace "fish" with "xyzw"
local writer = io.writer_from_buffer(a_buffer, 4, 4)

local out_buf = buffer.fromstring("xyzw 123")
local written = writer:write(out_buf)

assert(written == 4, `Expected to write 4, wrote {written}`)

local expected = "one xyzw two fish red fish blue fis"
assert(buffer.tostring(a_buffer) == expected, `Expected "{expected}", got "{buffer.tostring(a_buffer)}"`)
