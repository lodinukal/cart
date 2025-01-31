--!strict
local process = {}

export type Term = {
	type: "Exited" | "Signal" | "Stopped" | "Unknown",
	code: number,
}

export type Child = {
	wait: (self: Child) -> Term,
	kill: (self: Child) -> (),
	term: (self: Child) -> Term?,
}

function process.argv(): { string }
	return {}
end

function process.getenv(name: string): string?
	local _ = name
	return nil
end

function process.exit(code: number?)
	local _ = code
end

function process.spawn(name: string, args: { string }): Child
	local _ = name
	local _ = args
	return nil :: any
end

return process
