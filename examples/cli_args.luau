local process = require("@cart/process")

local args = process.argv()
for i, arg in ipairs(args) do
	print(i, arg)
end
