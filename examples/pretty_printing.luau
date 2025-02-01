local pretty = require("@cart/pretty")

local my_custom_object = {
	__type = "MyCustomObject",
	x = 10,
	y = 20,
}

local function format_my_custom_object(value, _: pretty.PrintOptions): string?
	if typeof(value) == "table" and value.__type == "MyCustomObject" then
		local v: typeof(my_custom_object) = value
		return "MyCustomObject { x = " .. v.x .. ", y = " .. v.y .. " }"
	end
	return nil
end

local bob = {
	name = "Bob",
	age = 30,
	likes = { "cats", "dogs", "birds", my_custom_object :: any },
}

local employees = {
	bob,
}

local company = {
	employees = employees,
}

print(pretty.print(company, {
	indent = "  ",
	formatters = { format_my_custom_object },
}))
