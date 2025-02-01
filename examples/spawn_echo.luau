local process = require("@cart/process")
local fs = require("@cart/fs")
local io = require("@cart/io")

local c = process.spawn("zig", { "zen" }, {
	stdout = "pipe",
})
print(`Current term: {c:term()}`)

local stdout_reader = c:stdout()
if stdout_reader then
	local file = fs.open_file("zig_zen.temp.txt", {
		create_if_not_exists = true,
		truncate_if_exists = true,
	})
	assert(file, "Failed to open file")
	io.pipe(stdout_reader, file:writer())
end

local term = c:wait()
print("Child process exited as " .. tostring(term.type) .. " with code " .. tostring(term.code))

local c2 = process.spawn("zig", { "zen" }, {})
c2:kill()
local c2_term = c2:term()
local c2_term_type = c2_term and c2_term.type or "nil"
local c2_term_code = c2_term and c2_term.code or "nil"
print("Child process 2 exited as " .. c2_term_type .. " with code " .. c2_term_code)
