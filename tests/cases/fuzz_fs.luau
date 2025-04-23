local fs = require("@cart/fs")
local random = math.random

-- Helper function to generate random strings
local function randomstring(length)
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local str = ""
	for _ = 1, length do
		local idx = random(1, #chars)
		str = str .. chars:sub(idx, idx)
	end
	return str
end

-- Fuzz test for creating and deleting files
for _ = 1, 100 do
	local filename = randomstring(10) .. ".temp.txt"
	local create_res = fs.createfile(filename, { mode = "readwrite", create = true })
	assert(create_res.ok, `Failed to create file {filename}`)
	assert(create_res.value, `File handle not returned for {filename}`)

	local delete_res = fs.delete(filename)
	assert(delete_res.ok, `Failed to delete file {filename}`)
end

-- Fuzz test for invalid file operations
for _ = 1, 50 do
	local invalid_filename = randomstring(15) .. ".invalid"
	local open_res = fs.openfile(invalid_filename, { mode = "readonly", create = false })
	assert(not open_res.ok, `Unexpected success opening invalid file {invalid_filename}`)
	assert(open_res.why == "FileNotFound", `Unexpected error kind for {invalid_filename}`)
end

-- Fuzz test for random paths in makepath
for _ = 1, 50 do
	local random_path = "test_dir/" .. randomstring(8) .. "/nested/" .. randomstring(5)
	local makepath_res = fs.makepath(random_path)
	assert(makepath_res.ok, `Failed to create path {random_path}`)

	local delete_res = fs.delete("test_dir/")
	assert(delete_res.ok, `Failed to delete path test_dir/`)
end

-- Fuzz test for symlinks
for _ = 1, 50 do
	local target_file = randomstring(10) .. ".target.txt"
	local symlink_file = randomstring(10) .. ".symlink.txt"

	local create_res = fs.createfile(target_file, { mode = "readwrite", create = true })
	assert(create_res.ok, `Failed to create target file {target_file}`)

	local symlink_res = fs.symlinkfile(target_file, symlink_file)
	assert(symlink_res.ok, `Failed to create symlink {symlink_file} to {target_file}`)

	local delete_res = fs.delete(target_file)
	assert(delete_res.ok, `Failed to delete target file {target_file}`)

	local delete_symlink_res = fs.delete(symlink_file)
	assert(delete_symlink_res.ok, `Failed to delete symlink file {symlink_file}`)
end

-- Fuzz test for hardlinks
for _ = 1, 50 do
	local target_file = randomstring(10) .. ".target.txt"
	local hardlink_file = randomstring(10) .. ".hardlink.txt"

	local create_res = fs.createfile(target_file, { mode = "readwrite", create = true })
	assert(create_res.ok, `Failed to create target file {target_file}`)

	local hardlink_res = fs.hardlinkfile(target_file, hardlink_file)
	assert(hardlink_res.ok, `Failed to create hardlink {hardlink_file} to {target_file}`)

	local delete_res = fs.delete(target_file)
	assert(delete_res.ok, `Failed to delete target file {target_file}`)

	local delete_hardlink_res = fs.delete(hardlink_file)
	assert(delete_hardlink_res.ok, `Failed to delete hardlink file {hardlink_file}`)
end
