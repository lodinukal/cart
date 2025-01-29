local sys = require("@cart/sys")

local args = sys.argv()
for i, arg in ipairs(args) do
	print(i, arg)
end
