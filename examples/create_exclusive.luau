local fs = require("@cart/fs")

local success, file_or_err = pcall(fs.create_file, "opening.temp.txt", {
	open_mode = "read_write" :: "read_write",
	exclusive = true,
})
print(success)
if not success then
	print("Failed to open file:", file_or_err)
	return
end

local writer = file_or_err:writer()
writer:write(buffer.fromstring("Exclusive write test\n"))
