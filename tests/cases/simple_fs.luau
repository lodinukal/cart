local fs = require("@cart/fs")

assert(fs.openfile, "fs.openfile should exist")
assert(fs.createfile, "fs.createfile should exist")
assert(fs.makepath, "fs.makepath should exist")
assert(fs.delete, "fs.delete should exist")
assert(fs.kindpath, "fs.kindpath should exist")
assert(fs.symlinkfile, "fs.symlinkfile should exist")
assert(fs.symlinkdir, "fs.symlinkdir should exist")
assert(fs.hardlinkfile, "fs.hardlinkfile should exist")
assert(fs.hardlinkdir, "fs.hardlinkdir should exist")

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

assert(res.value:tell() == 0, "file should be at the start")
res.value:write("hello world")
assert(res.value:tell() == 11, `file should be at the end after write, is at {res.value:tell()}`)

local seek_end_res = res.value:seekend(0)
assert(seek_end_res.ok, "seek to end should be ok")
assert(res.value:tell() == 11, "file should be at the end after seek")

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
assert(open_symlink_res.value:tell() == 0, "file should be at the start")
assert(open_symlink_res.value:kind() == "file", "kind should be file")
open_symlink_res.value:seekend(0)
assert(open_symlink_res.value:tell() == 11, "file should be at the end after seek")
open_symlink_res.value:close()
fs.delete("greeting_symlink.temp.txt")

local seek_res = res.value:seek(0)
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
assert(read_hardlink_res.value:tell() == 0, "file should be at the start")
local read_hardlink_value = buffer.create(5)
local read_hardlink = read_hardlink_res.value:read(read_hardlink_value)
assert(read_hardlink.ok, "readfile should be ok")
assert(read_hardlink.value == 5, "readfile should return 5")
local read_hardlink_value_str = buffer.tostring(read_hardlink_value)
assert(
	read_hardlink_value_str == "hello",
	`readfile should return the correct value of hello, got "{read_hardlink_value_str}"`
)
read_hardlink_res.value:close()
fs.delete("greeting_hardlink.temp.txt")

local read_buffer = buffer.create(5)
local read_res = res.value:read(read_buffer)
assert(read_res.ok, "readfile should be ok")
assert(read_res.value == 5, "readfile should return a value")
local read_value = buffer.tostring(read_buffer)
assert(read_value == "hello", `readfile should return the correct value of hello, got "{read_value}"`)

res.value:seek(0)
local read_all_res = res.value:readtoend()
assert(read_all_res.ok, "readall should be ok")
assert(read_all_res.value, "readall should return a value")
local read_all_value = buffer.tostring(read_all_res.value)
assert(
	read_all_value == "hello world",
	`readall should return the correct value of hello world, got "{read_all_value}"`
)

local make_path_res = fs.makepath("test_path/nested/")
assert(make_path_res.ok, "makepath should be ok")
fs.delete("test_path/")

assert(#res.value:relpath() > 0, "file should have a relative path")
assert(#res.value:abspath() > 0, "file should have an absolute path")

assert(res.value:kind() == "file", "kind should be file")

fs.delete("greeting.temp.txt")

local lock_res = res.value:lock("exclusive")
assert(lock_res.ok, "lock should be ok")
res.value:unlock()

local trylock_res = res.value:trylock("exclusive")
assert(trylock_res.ok, "trylock should be ok")

local second_trylock_res = res.value:trylock("exclusive")
assert(second_trylock_res.ok == true, "trylock should succeed but return false when file is already locked")
assert(second_trylock_res.value == false, "trylock should not lock the file again")
res.value:unlock()

-- readonly test, make a file, write some contents, set it to readonly, and check if it fails to write
local readonly_file_create_res = fs.createfile("readonly.temp.txt", {
	mode = "readwrite",
	create = true,
})
assert(readonly_file_create_res.ok, "createfile should be ok")
assert(readonly_file_create_res.value, "createfile should return a file")

readonly_file_create_res.value:write("hello world")
assert(readonly_file_create_res.value:tell() == 11, "file should be at the end after write")
local set_readonly_res = readonly_file_create_res.value:setreadonly(true)
assert(set_readonly_res.ok, "setreadonly should be ok")
assert(readonly_file_create_res.value:isreadonly() == true, "file should be readonly")
readonly_file_create_res.value:close()

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

local abspath = res.value.abspath
assert(res.value:close() == true, "file should close successfully")
assert(res.value:close() == false, "file should be closed and return false on additional close")

local success = pcall(function()
	abspath(newproxy(true))
end)
assert(success == false, `fs functions should fail if passed file is not a file handle`)
