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

local function format_fizz_buzz_number(value, _: pretty.PrintOptions): string?
	if typeof(value) == "number" then
		local v: number = value
		if v % 3 == 0 and v % 5 == 0 then
			return "fizzbuzz()"
		elseif v % 3 == 0 then
			return "fizz()"
		elseif v % 5 == 0 then
			return "buzz()"
		end
	end
	return nil
end
local _ = format_fizz_buzz_number

local bob = {
	name = "Bob",
	age = 30,
	likes = { "cats", "dogs", "birds", my_custom_object :: any, 15 :: any, 31 :: any },
	["birth year"] = 1990,
	["fizz buzz"] = 15,
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
