local sys = require("@cart/sys")
local ffi = require("@cart/ffi")

if sys.get_os() == "wasi" then
	assert(ffi.supported == false, "FFI should not be supported on WASI")
	assert(ffi.structure == nil, "ffi.structure should not be defined on WASI")
else
	assert(ffi.supported == true, "FFI should be supported on non-WASI platforms")
	assert(typeof(ffi.structure) == "function", "ffi.structure should be defined on non-WASI platforms")
end

print("FFI as expected")
