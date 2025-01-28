--!strict
local io = require("io")
local net = {}

export type Method = "GET" | "POST" | "PUT" | "DELETE" | "PATCH"
export type FetchOptions = {
	method: Method?,
	headers: { [string]: string }?,
	body: buffer?,
}

--- @note This function will suspend the current thread.
--- @param url The URL to fetch.
--- @param options The options to use when fetching the URL.
--- @returns The response body.
function net.fetch(url: string, options: FetchOptions): io.Reader
	local _ = url
	local _ = options
	return nil :: any
end

return net
