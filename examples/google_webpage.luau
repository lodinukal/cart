local net = require("@cart/net")
local pretty = require("@cart/pretty")
local fs = require("@cart/fs")

local socket_res = net.tcp("ipv4")
assert(socket_res.ok, "socket creation failed")
local socket = socket_res.value

local google_addresses = net.resolveaddress("http://www.google.com:80")
assert(google_addresses.ok, "resolveaddress failed: " .. pretty.print(google_addresses, {}))
local first_address = google_addresses.value[1]

-- http
local connect_res = socket:connect(first_address.address, first_address.port)
assert(connect_res.ok, "socket connect failed: " .. pretty.print(connect_res, {}))

local reader = socket:reader()
local writer = socket:writer()

-- write a http request
local request = [[
GET / HTTP/1.1
Connection: close
User-Agent: Cart luau runtime

]]
local send_buffer = buffer.fromstring(request)
local send_res = writer:write(send_buffer)
if not send_res.ok then
	print("send failed: " .. pretty.print(send_res, {}))
	socket:close()
end

local final_document = ""
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
	final_document = final_document .. buffer.readstring(out_buffer, 0, len)

	total = total + len
end

local file_res = fs.openfile("google.temp.txt", {
	mode = "writeonly",
	create = true,
})
assert(file_res.ok, "createfile failed: " .. pretty.print(file_res, {}))
local file = file_res.value
print("preparing to write " .. #final_document .. " bytes to file")
local write_res = file:write(final_document)
print("wrote " .. #final_document .. " bytes to file")
assert(write_res.ok, "write failed: " .. pretty.print(write_res, {}))
file:close()

socket:close()
