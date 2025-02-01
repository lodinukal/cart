local fs = require("@cart/fs")

local success, file_or_err = pcall(fs.create_file, "opening.temp.txt", {
	open_mode = "read_write" :: "read_write",
	exclusive = true,
})
if not success then
	local fs_err = fs.error:as(file_or_err)
	if fs_err then
		local e = fs_err:get()
		print(`Error writing to {e.path} because {e.kind}`)
	end
	return
end

local writer = file_or_err:writer()
writer:write(buffer.fromstring("Exclusive write test\n"))
