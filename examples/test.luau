local fs = require("@cart/fs")
local task = require("@cart/task")

print(`{fs.kind("help.temp.txt")} help`)
print(`{fs.kind("help2.temp.txt")} help2`)
print(`{fs.kind("help3.temp.txt")} help3`)

local file = fs.open_file("help.temp.txt", {
	create_if_not_exists = true,
})
local reader = file:reader()

local buf = buffer.create(1024)
while reader:read(buf) > 0 do
	print(buffer.tostring(buf))
end

local file2 = fs.open_file("help.temp.txt", {
	open_mode = "write_only",
	lock = "exclusive",
	truncate_if_exists = true,
})
local writer = file2:writer()
writer:write(buffer.fromstring("hello this is a test"))

local function await(t: thread)
	while coroutine.status(t) ~= "dead" do
		task.wait(0)
	end
end

local function xthen(t: thread, f: (thread) -> ())
	task.spawn(function()
		await(t)
		f(t)
	end)
end

local task1 = task.spawn(function()
	for i = 1, 3 do
		task.wait(1)
		print(i)
	end
end)
xthen(task1, function()
	print("done")
end)

-- local file = fs.open_file("help.temp.txt", {})
-- assert(file, "Failed to open file")
-- fs.closeFile(file)

-- local my_buffer = buffer.fromstring("hello")

-- local writer = file.writer(file)
-- assert(writer, "Failed to get writer")
-- writer:write(my_buffer)

-- print(fs.getPermissions(file, "user"))

-- print("hello")
