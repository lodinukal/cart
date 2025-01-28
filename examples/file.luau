local fs = require("@cart/fs")
fs.open_file("file.temp.txt", {
	create_if_not_exists = true,
	open_mode = "read_write",
})
	:writer()
	:write(buffer.fromstring("hello world"))
