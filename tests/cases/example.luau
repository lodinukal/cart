-- error("SKIPTEST", 0)
local adder_lib = require("./adder")
assert(adder_lib.add(1, 2) == 3)

return {}
