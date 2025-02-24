local web = require("@cart/web")

local my_add = web.export("my_add")

print(`my_add(1, 2) = {my_add:call(1, 2):unmarshal()}`)
