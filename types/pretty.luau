--!strict
local pretty = {}

--- Formatter function type.
--- Return nil to delegate formatting to the next formatter.
export type Formatter = (value: any, options: PrintOptions) -> string?

export type PrintOptions = {
	current_depth: number?,
	indent: string?,
	formatters: { Formatter }?,
}

--- Pretty prints a value.
function pretty.print(value: any, options: PrintOptions): string
	local _ = value
	local _ = options
	return ""
end

return pretty
