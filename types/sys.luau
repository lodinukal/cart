--!strict
local sys = {}

export type OperatingSystem = "windows" | "macos" | "linux" | "android" | "ios" | "wasi" | "unknown"

function sys.get_os(): OperatingSystem
	return "unknown"
end

return sys
