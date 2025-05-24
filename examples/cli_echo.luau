local fs = require("@cart/fs")
local pretty = require("@cart/pretty")

local stdin = fs.stdin()

local b = buffer.create(1024)
while true do
	local read_ok = stdin:read(b)
	if not read_ok.ok then
		print("read failed: " .. pretty.print(read_ok, {}))
		break
	end
	local read_string = buffer.readstring(b, 0, read_ok.value)
	if read_string:match("\r\n") then
		read_string = read_string:gsub("\r\n", "\n")
	end

	if read_string:match("\n") then
		read_string = read_string:gsub("\n", "")
	end

	if #read_string == 0 then
		print("EOF")
		break
	end

	print("read " .. #read_string .. " bytes")
	print("data: " .. read_string)
end
