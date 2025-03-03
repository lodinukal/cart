local json = require("@cart/json")
local pretty = require("@cart/pretty")

local object = {
	name = "Bob",
	age = 20,
	is_employee = true,
	performance = { 90, 95, 100 },
}

local encoded = json.encode(object)
print(encoded)

local decoded = json.decode(encoded)
print(pretty.print(decoded, {}))

return encoded
