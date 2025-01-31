local web = require("@cart/web")
-- local task = require("@cart/task")

local document = web.global("document")
local body = document:get("body")

local button = document:invoke("createElement", "button")
button:set("textContent", "Click me!")
body:invoke("appendChild", button)

local console = web.global("console")

local event_listener
local count = 0
local function clickListener(_ev: web.Handle)
	count += 1
	console:invoke("log", "Clicked " .. count .. " times")
	button:set("textContent", "Count " .. count)

	if count < 5 then
		return
	end
	count = 0
	console:invoke("log", "Resetting")
	-- button:invoke("removeEventListener", "click", event_listener)
end
event_listener = web.marshal(clickListener)

button:invoke("addEventListener", "click", event_listener)
