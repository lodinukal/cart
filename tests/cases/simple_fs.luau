local fs = require("@cart/fs")

assert(fs.openfile, "fs.openfile should exist")
assert(fs.createfile, "fs.createfile should exist")
assert(fs.closefile, "fs.closefile should exist")
assert(fs.makepath, "fs.makepath should exist")
assert(fs.delete, "fs.delete should exist")
assert(fs.writefile, "fs.writefile should exist")
assert(fs.appendfile, "fs.appendfile should exist")
assert(fs.readfile, "fs.readfile should exist")
assert(fs.abspath, "fs.abspath should exist")
assert(fs.relpath, "fs.relpath should exist")
assert(fs.tell, "fs.tell should exist")
assert(fs.seek, "fs.seek should exist")
assert(fs.seekend, "fs.seekend should exist")
assert(fs.kind, "fs.kind should exist")
assert(fs.kindpath, "fs.kindpath should exist")
assert(fs.lock, "fs.lock should exist")
assert(fs.trylock, "fs.trylock should exist")
assert(fs.unlock, "fs.unlock should exist")
assert(fs.symlinkfile, "fs.symlinkfile should exist")
assert(fs.symlinkdir, "fs.symlinkdir should exist")
assert(fs.hardlinkfile, "fs.hardlinkfile should exist")
assert(fs.hardlinkdir, "fs.hardlinkdir should exist")
assert(fs.isreadonly, "fs.isreadonly should exist")
assert(fs.setreadonly, "fs.setreadonly should exist")

local file_1 = fs.openfile("doesnt_exist.temp.txt", {
	mode = "readwrite",
	create = false,
})

assert(file_1.ok == false, "openfile should fail if file does not exist")
assert(file_1.why, "openfile should return an error")
assert(file_1.why == "FileNotFound", `openfile should return a FileNotFound error: {file_1.explanation}`)
assert((file_1 :: any).value == nil, "openfile should return nil if it fails")
assert(
	file_1.explanation == `Failed to open file \`doesnt_exist.temp.txt\` because file was not found`,
	"openfile should return an explanation"
)

local kindpath_non_existent = fs.kindpath("doesnt_exist.temp.txt")
assert(kindpath_non_existent == nil, `kindpath should return nil if file does not exist, got {kindpath_non_existent}`)

local res_invalid_args = fs.openfile("wont_ever.temp.txt", {
	mode = "readwrite",
	create = true,
	lock = "invalid" :: any,
})
assert(res_invalid_args.ok == false, "openfile should fail if file does not exist")
assert(res_invalid_args.why, "openfile should return an error")
assert(
	res_invalid_args.why == "InvalidArgument",
	`openfile should return an InvalidArgument error, got {res_invalid_args.why}`
)
assert(
	res_invalid_args.explanation == "Invalid lock `invalid`",
	`openfile should return an explanation, got {res_invalid_args.explanation}`
)

local ephemeral = fs.createfile("ephemeral.temp.txt", {
	mode = "readwrite",
	create = true,
})
assert(ephemeral.ok, "createfile should be ok")
assert(ephemeral.value, "createfile should return a file")

local kind_ephemeral_1 = fs.kindpath("ephemeral.temp.txt")
assert(kind_ephemeral_1, "kindpath should return a result")
assert(kind_ephemeral_1 == "file", "kindpath should return file kind")

fs.delete("ephemeral.temp.txt")
local kind_ephemeral_2 = fs.kindpath("ephemeral.temp.txt")
assert(kind_ephemeral_2 == nil, "kindpath should return nil if file does not exist")

local res = fs.createfile("greeting.temp.txt", {
	mode = "readwrite",
	truncate = true,
})

assert(res, "createfile should return a result")
assert(res.ok, "createfile should be ok")
assert(res.value, "createfile should return a file")

assert(fs.tell(res.value) == 0, "file should be at the start")
fs.writefile(res.value, "hello world")
assert(fs.tell(res.value) == 11, `file should be at the end after write, is at {fs.tell(res.value)}`)

local seek_end_res = fs.seekend(res.value, 0)
assert(seek_end_res.ok, "seek to end should be ok")
assert(fs.tell(res.value) == 11, "file should be at the end after seek")

-- make a symlink to the file and check if the size is the same
local symlink_res = fs.symlinkfile("greeting.temp.txt", "greeting_symlink.temp.txt")
assert(symlink_res.ok, "symlink should be ok")

local symlink_kind = fs.kindpath("greeting_symlink.temp.txt")
assert(symlink_kind, "kindpath should return a result")
assert(symlink_kind == "file", "kindpath should return file kind")

local open_symlink_res = fs.openfile("greeting_symlink.temp.txt", {
	mode = "readonly",
	create = false,
})
assert(open_symlink_res.ok, `openfile should be ok`)
assert(open_symlink_res.value, "openfile should return a file")
assert(fs.tell(open_symlink_res.value) == 0, "file should be at the start")
assert(fs.kind(open_symlink_res.value) == "file", "kind should be file")
fs.seekend(open_symlink_res.value, 0)
assert(fs.tell(open_symlink_res.value) == 11, "file should be at the end after seek")
fs.closefile(open_symlink_res.value)
fs.delete("greeting_symlink.temp.txt")

local seek_res = fs.seek(res.value, 0)
assert(seek_res.ok, "seek to start should be ok")

local hardlink_res = fs.hardlinkfile("greeting.temp.txt", "greeting_hardlink.temp.txt")
assert(hardlink_res.ok, "hardlink should be ok")

-- read contents of hardlink
local read_hardlink_res = fs.openfile("greeting_hardlink.temp.txt", {
	mode = "readonly",
	create = false,
})
assert(read_hardlink_res.ok, "openfile should be ok")
assert(read_hardlink_res.value, "openfile should return a file")
assert(fs.tell(read_hardlink_res.value) == 0, "file should be at the start")
local read_hardlink_value = fs.readfile(read_hardlink_res.value, 5)
assert(read_hardlink_value.ok, "readfile should be ok")
assert(read_hardlink_value.value, "readfile should return a value")
assert(typeof(read_hardlink_value.value) == "buffer", "readfile should return a buffer")
local read_hardlink_value_str = buffer.tostring(read_hardlink_value.value)
assert(
	read_hardlink_value_str == "hello",
	`readfile should return the correct value of hello, got "{read_hardlink_value_str}"`
)
fs.closefile(read_hardlink_res.value)
fs.delete("greeting_hardlink.temp.txt")

local read_res = fs.readfile(res.value, 5)
assert(read_res.ok, "readfile should be ok")
assert(read_res.value, "readfile should return a value")
assert(typeof(read_res.value) == "buffer", "readfile should return a buffer")
local read_value = buffer.tostring(read_res.value)
assert(read_value == "hello", `readfile should return the correct value of hello, got "{read_value}"`)

local make_path_res = fs.makepath("test_path/nested/")
assert(make_path_res.ok, "makepath should be ok")
fs.delete("test_path/")

assert(#fs.relpath(res.value) > 0, "file should have a relative path")
assert(#fs.abspath(res.value) > 0, "file should have an absolute path")

assert(fs.kind(res.value) == "file", "kind should be file")

fs.delete("greeting.temp.txt")

local lock_res = fs.lock(res.value, "exclusive")
assert(lock_res.ok, "lock should be ok")
fs.unlock(res.value)

local trylock_res = fs.trylock(res.value, "exclusive")
assert(trylock_res.ok, "trylock should be ok")

local second_trylock_res = fs.trylock(res.value, "exclusive")
assert(second_trylock_res.ok == true, "trylock should succeed but return false when file is already locked")
assert(second_trylock_res.value == false, "trylock should not lock the file again")
fs.unlock(res.value)

-- readonly test, make a file, write some contents, set it to readonly, and check if it fails to write
local readonly_file_create_res = fs.createfile("readonly.temp.txt", {
	mode = "readwrite",
	create = true,
})
assert(readonly_file_create_res.ok, "createfile should be ok")
assert(readonly_file_create_res.value, "createfile should return a file")

fs.writefile(readonly_file_create_res.value, "hello world")
assert(fs.tell(readonly_file_create_res.value) == 11, "file should be at the end after write")
local set_readonly_res = fs.setreadonly(readonly_file_create_res.value, true)
assert(set_readonly_res.ok, "setreadonly should be ok")
assert(fs.isreadonly(readonly_file_create_res.value) == true, "file should be readonly")
fs.closefile(readonly_file_create_res.value)

local readonly_file_res = fs.openfile("readonly.temp.txt", {
	mode = "readwrite",
})
assert(readonly_file_res.ok == false, "openfile should fail if file is readonly")
assert(readonly_file_res.why, "openfile should return an error")
assert(
	readonly_file_res.why == "AccessDenied",
	`openfile should return a AccessDenied error, got {readonly_file_res.why}`
)
assert(
	readonly_file_res.explanation == "Failed to open file `readonly.temp.txt` because access denied",
	`openfile should return an explanation, got {readonly_file_res.explanation}`
)

fs.delete("readonly.temp.txt")

assert(fs.closefile(res.value) == true, "file should close successfully")
assert(fs.closefile(res.value) == false, "file should be closed and return false on additional close")

local success = pcall(function()
	fs.abspath(newproxy(true))
end)
assert(success == false, `fs functions should fail if passed file is not a file handle`)
