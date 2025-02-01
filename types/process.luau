--!strict
local process = {}
local io = require("io")

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
	--- async only on non wasi targets, otherwise sync
	wait: (self: Child) -> Term,
	kill: (self: Child) -> (),
	term: (self: Child) -> Term?,

	--- Must be called and used prior to waiting and killing
	stdin: (self: Child) -> io.Writer?,
	--- Must be called and used prior to waiting and killing
	stdout: (self: Child) -> io.Reader?,
	--- Must be called and used prior to waiting and killing
	stderr: (self: Child) -> io.Reader?,
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

function process.spawn(name: string, args: { string }, options: SpawnOptions): Child
	local _ = name
	local _ = args
	local _ = options
	return nil :: any
end

return process
