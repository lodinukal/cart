local sys = require("@cart/sys")
if sys.os ~= "linux" then
	error("SKIPTEST", 0)
end

local fs = require("@cart/fs")

local rand_res = fs.openfile("/dev/random", {})
assert(rand_res.ok, "openfile should be ok")
assert(rand_res.value, "openfile should return a file")

local rand_file = rand_res.value
rand_file:seek(10)
assert(rand_file:tell() == 0, "even when seeked, /dev/random should be told 0")

local buf = buffer.create(16)
local read_res = rand_file:read(buf)
assert(read_res.ok, "readfile should be ok")
local a = buffer.readu32(buf, 0)
local b = buffer.readu32(buf, 4)
local c = buffer.readu32(buf, 8)
local d = buffer.readu32(buf, 12)
print(a .. " " .. b .. " " .. c .. " " .. d)
