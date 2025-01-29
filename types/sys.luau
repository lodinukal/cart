--!strict
local sys = {}

export type OperatingSystem = "windows" | "macos" | "linux" | "android" | "ios" | "wasi" | "unknown"

function sys.get_os(): OperatingSystem
	return "unknown"
end

function sys.argv(): { string }
	return {}
end

function sys.getenv(name: string): string?
	local _ = name
	return nil
end

return sys
