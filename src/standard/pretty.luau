--!strict
local pretty = {}

export type Context = "lvalue" | "rvalue"
export type Formatter = (value: any, options: PrintOptions) -> string?
export type PrintOptions = {
	current_depth: number?,
	indent: string?,
	visited_tables: { [any]: true },
	formatters: { Formatter },
	context: Context?,
}

function pretty.print(value: any, options: PrintOptions): string
	local current_depth = options.current_depth or 0
	local indent = options.indent or "\t"
	local visited_tables = options.visited_tables or {}

	local formatters = options.formatters or {}
	for _, formatter in ipairs(formatters) do
		local formatted = formatter(value, options)
		if formatted then
			return formatted
		end
	end

	-- Default formatter
	local ty = typeof(value)
	if ty == "table" then
		if visited_tables[value] then
			return "<circular reference>"
		end
		visited_tables[value] = true
		local str = "{\n"
		for k, v in pairs(value) do
			local kv_options: PrintOptions = {
				current_depth = current_depth + 1,
				indent = indent,
				visited_tables = visited_tables,
				formatters = formatters,
			}
			kv_options.context = "lvalue"
			local key = pretty.print(k, kv_options)
			kv_options.context = "rvalue"
			local val = pretty.print(v, kv_options)

			local key_doesnt_need_brackets = typeof(k) == "string" and k:match("^[%a_][%a%d_]*$") ~= nil
			str = str .. indent:rep(current_depth)
			if key_doesnt_need_brackets then
				str = str .. k
			else
				str = str .. "[" .. key .. "]"
			end
			str = str .. " = " .. val .. ",\n"
		end
		str = str .. indent:rep(current_depth - 1) .. "}"
		return str
	elseif ty == "string" then
		return '"' .. value .. '"'
	else
		return tostring(value)
	end
end

return pretty
