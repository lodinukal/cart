local net = require("@cart/net")
local pretty = require("@cart/pretty")

local socket_res = net.socket("ipv4", "tcp")
assert(socket_res.ok, "socket creation failed")
local socket = socket_res.value
socket:bind("0.0.0.0:1166")
socket:listen()
print(pretty.print(socket, {}))

local function echoclient(client: Socket)
	local client_endpoint_res = client:getremoteendpoint()
	assert(client_endpoint_res.ok, "getremoteendpoint failed")
	local client_endpoint = client_endpoint_res.value

	local reader = client:reader()
	local writer = client:writer()

	local buf = buffer.create(1024)
	while true do
		local res = reader:read(buf)
		if not res.ok then
			print("receive failed: " .. (res.explanation or "?"))
			break
		end
		local len = res.value
		if len == 0 then
			break
		end

		print("received " .. len .. " bytes from " .. tostring(client_endpoint))
		print("data: " .. buffer.readstring(buf, 0, len))
		writer:write(buf, len)
	end
	print("client " .. client_endpoint .. " disconnected")
end

while true do
	local client_res = socket:accept()
	assert(client_res.ok, "accept failed")
	local client = client_res.value

	echoclient(client)

	client:close()
end

socket:close()
