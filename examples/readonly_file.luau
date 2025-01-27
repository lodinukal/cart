local fs = require("@cart/fs")
local file = fs.openFile("readonly.temp.txt", {
	create_if_not_exists = true,
	open_mode = "read_only",
})
file:setReadonly(false)
print(`{file:getReadonly()} readonly`)
-- file:setReadonly(true)
print(`{file:getReadonly()} readonly`)
-- file:setReadonly(false)
print(`{file:getReadonly()} readonly`)

fs.deleteFile("readonly.temp.txt")
