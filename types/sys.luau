--!strict
export type OperatingSystem = "windows" | "macos" | "linux" | "android" | "ios" | "wasi" | "unknown"
local sys = {
	os = "unknown" :: OperatingSystem,
}

return sys
