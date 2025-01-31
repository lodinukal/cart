--!strict
local process = {}

export type IoBehavior = "inherit" | "ignore" | "pipe"

export type SpawnOptions = {
	cwd: string?,
	env: { string: string }?,
	stdin: IoBehavior?,
	stdout: IoBehavior?,
	stderr: IoBehavior?,
}

export type Term = {
	type: "exited" | "signal" | "stopped" | "unknown",
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

function process.spawn(name: string, args: { string }?, options: SpawnOptions?): Child
	local _ = name
	local _ = args
	local _ = options
	return nil :: any
end

return process
