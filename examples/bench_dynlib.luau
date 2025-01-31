local ffi = require("@cart/ffi")

local lib = ffi.open("zig-out/bin/shared_test.dll")
assert(lib, "Failed to open shared library")

local lua_lib: { add: (number, number) -> number }? = lib:load("open")
assert(lua_lib, "Failed to find add")

local start = os.clock()
local result = lua_lib.add(1, 2)
local elapsed = os.clock() - start

local frame_budget = 60 / elapsed
elapsed = elapsed

print("Result:", result)
print("Elapsed:", elapsed)
print("Frame budget:", frame_budget)
