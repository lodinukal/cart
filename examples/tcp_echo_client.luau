local net = require("@cart/net")
local pretty = require("@cart/pretty")

local socket_res = net.tcp("ipv4")
assert(socket_res.ok, "socket creation failed")
local socket = socket_res.value

socket:connect("127.0.0.1", 1166)

local reader = socket:reader()
local writer = socket:writer()

local words = {
	"apple",
	"banana",
	"cherry",
	"date",
	"elderberry",
	"fig",
}
local want = 2
local join = {}
for i = 1, want do
	local rand = math.random(1, #words)
	table.insert(join, words[rand])
end
local key = table.concat(join, "-")

local send_buffer = buffer.fromstring(key)
writer:write(send_buffer)

local out_buffer = buffer.create(1024)
local total = 0
while true do
	local recv_res = reader:read(out_buffer)
	if not recv_res.ok then
		if recv_res.why == "EOF" then
			print("server disconnected")
			socket:close()
			break
		end
		print("receive failed: " .. pretty.print(recv_res, {}))
		socket:close()
		break
	end

	local len = recv_res.value
	print("received " .. len .. " bytes")
	print("data: " .. buffer.readstring(out_buffer, 0, len))

	total = total + len
	if total >= #key then
		print("all data received")
		break
	end
end

socket:close()
