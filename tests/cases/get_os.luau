local sys = require("@cart/sys")

local found = false
local os = sys.os
for _, v in ipairs({ "windows", "macos", "linux", "android", "ios", "wasi", "unknown" }) do
	if os == v then
		found = true
		break
	end
end

assert(found, "os is not one of the expected values")
assert(type(os) == "string", "os is not a string")
