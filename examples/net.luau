local net = require("@cart/net")
local fs = require("@cart/fs")
local io = require("@cart/io")

local random_todo_id = math.random(1, 200)

local reader = net.fetch("https://jsonplaceholder.typicode.com/todos/" .. tostring(random_todo_id), {
	method = "GET",
	headers = {
		["User-Agent"] = "Mozilla/5.0",
	},
})

local output_file = fs.open_file("example.temp.txt", {
	create_if_not_exists = true,
	truncate_if_exists = true,
	open_mode = "read_write",
})

io.pipe(reader, output_file:writer(), function(written)
	print(`Written {written} bytes`)
	return true
end, 100)
