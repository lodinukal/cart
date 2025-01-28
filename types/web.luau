local web = {}

local console = {}

function console.log(...)
	local _ = select("#", ...)
end

function console.error(...)
	local _ = select("#", ...)
end

web.console = console

return web
