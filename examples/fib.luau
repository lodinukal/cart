local sys = require("@cart/sys")

local function fib(n: number): number
	local a = 0
	local b = 1
	for _ = 1, n do
		local c = a + b
		a = b
		b = c
	end
	return a
end

local args = sys.argv()
local it = tonumber(args[3]) or 10
print(`fib({it}) = {fib(it)}`)
