local sys = require("@cart/sys")
if sys.get_os() == "wasi" then
	error("This example is not supported on WASI, CORS policy blocks the request.")
	return
end

local fs = require("@cart/fs")
local net = require("@cart/net")
local io = require("@cart/io")

local reader = net.fetch(
	"https://github.com/KhronosGroup/glTF-Sample-Models/blob/main/2.0/AnimatedCube/glTF/AnimatedCube_BaseColor.png?raw=true",
	{
		method = "GET",
		headers = {
			["Content-Type"] = "image/png",
		},
	}
)

local output_file = fs.open_file("image.temp.png", {
	create_if_not_exists = true,
	truncate_if_exists = true,
	open_mode = "read_write",
})

io.pipe(reader, output_file:writer())
