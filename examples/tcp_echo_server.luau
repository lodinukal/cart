local net = require("@cart/net")
local pretty = require("@cart/pretty")

local socket_res = net.tcp("ipv4")
assert(socket_res.ok, "socket creation failed")
local socket = socket_res.value

socket:bind("0.0.0.0", 1166)
socket:listen(1)

local function echoclient(client_stream: TCPStream)
	local localendpoint = client_stream:getlocalendpoint()
	assert(localendpoint.ok, "getlocalendpoint failed because: " .. pretty.print(localendpoint, {}))
	local remoteendpoint = client_stream:getremoteendpoint()
	assert(remoteendpoint.ok, "getremoteendpoint failed because: " .. pretty.print(remoteendpoint, {}))
	print(`client connected from {remoteendpoint.value} ({localendpoint.value})`)

	local reader = client_stream:reader()
	local writer = client_stream:writer()

	local out_buffer = buffer.create(1024)
	while true do
		local recv_res = reader:read(out_buffer)
		if not recv_res.ok then
			if recv_res.why == "EOF" then
				print(`client disconnected from {remoteendpoint.value} ({localendpoint.value})`)
				client_stream:close()
				break
			end
			print("receive failed: " .. pretty.print(recv_res, {}))
			client_stream:close()
			break
		end

		local len = recv_res.value

		print("received " .. len .. " bytes")
		print("data: " .. buffer.readstring(out_buffer, 0, len))
		local send_res = writer:write(out_buffer, len)
		if not send_res.ok then
			print("send failed: " .. pretty.print(send_res, {}))
			client_stream:close()
			break
		end
	end
end

local main = coroutine.create(function()
	while true do
		print("waiting for connection...")
		local client_res = socket:accept()
		assert(client_res.ok, "accept failed: " .. pretty.print(client_res, {}))

		local cr = coroutine.create(echoclient)
		local ok, why = coroutine.resume(cr, client_res.value)
		if not ok then
			print("client failed: " .. tostring(why))
			client_res.value:close()
		end
	end
end)

coroutine.resume(main)
