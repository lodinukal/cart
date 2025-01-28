local fs = require("@cart/fs")
local file = fs.open_file("readonly.temp.txt", {
	create_if_not_exists = true,
	open_mode = "read_only",
})
file:set_readonly(false)
print(`{file:get_readonly()} readonly`)
-- file:setReadonly(true)
print(`{file:get_readonly()} readonly`)
-- file:setReadonly(false)
print(`{file:get_readonly()} readonly`)

fs.delete_file("readonly.temp.txt")
