local sys = require("@cart/sys")
if sys.get_os() == "wasi" then
	error("This is not supported on WASI.")
end

local ffi = require("@cart/ffi")

local lib = ffi.open("raylib")
assert(lib, "Failed to open raylib. Make sure to move the shared library to the current working directory.")

local CONFIG_FLAG = {
	VSYNC_HINT = 0x00000040, -- Set to try enabling V-Sync on GPU
	FULLSCREEN_MODE = 0x00000002, -- Set to run program in fullscreen
	WINDOW_RESIZABLE = 0x00000004, -- Set to allow resizable window
	WINDOW_UNDECORATED = 0x00000008, -- Set to disable window decoration (frame and buttons)
	WINDOW_HIDDEN = 0x00000080, -- Set to hide window
	WINDOW_MINIMIZED = 0x00000200, -- Set to minimize window (iconify)
	WINDOW_MAXIMIZED = 0x00000400, -- Set to maximize window (expanded to monitor)
	WINDOW_UNFOCUSED = 0x00000800, -- Set to window non focused
	WINDOW_TOPMOST = 0x00001000, -- Set to window always on top
	WINDOW_ALWAYS_RUN = 0x00000100, -- Set to allow windows running while minimized
	WINDOW_TRANSPARENT = 0x00000010, -- Set to allow transparent framebuffer
	WINDOW_HIGHDPI = 0x00002000, -- Set to support HighDPI
	WINDOW_MOUSE_PASSTHROUGH = 0x00004000, -- Set to support mouse passthrough, only supported when FLAG_WINDOW_UNDECORATED
	BORDERLESS_WINDOWED_MODE = 0x00008000, -- Set to run program in borderless windowed mode
	MSAA_4X_HINT = 0x00000020, -- Set to try enabling MSAA 4X
	INTERLACED_HINT = 0x00010000, -- Set to try enabling interlaced video format (for V3D)
}

local SetConfigFlags: ((number) -> ())? = lib:get("SetConfigFlags", "void", "sint")
assert(SetConfigFlags, "Failed to find SetConfigFlags")

local InitWindow: ((number, number, string) -> ())? = lib:get("InitWindow", "void", "sint", "sint", "pointer")
assert(InitWindow, "Failed to find InitWindow")

local SetTargetFPS: ((number) -> ())? = lib:get("SetTargetFPS", "void", "sint")
assert(SetTargetFPS, "Failed to find SetTargetFPS")

local CloseWindow: (() -> ())? = lib:get("CloseWindow", "void")
assert(CloseWindow, "Failed to find CloseWindow")

local WindowShouldClose: (() -> boolean)? = lib:get("WindowShouldClose", "bool8")
assert(WindowShouldClose, "Failed to find WindowShouldClose")

local BeginDrawing: (() -> ())? = lib:get("BeginDrawing", "void")
assert(BeginDrawing, "Failed to find BeginDrawing")

local EndDrawing: (() -> ())? = lib:get("EndDrawing", "void")
assert(EndDrawing, "Failed to find EndDrawing")

export type Color = { r: number, g: number, b: number, a: number }
local ColorT: ffi.Structure<Color> = ffi.structure("raylib.Color", {
	{ name = "r", ty = "uint8" },
	{ name = "g", ty = "uint8" },
	{ name = "b", ty = "uint8" },
	{ name = "a", ty = "uint8" },
})

local ClearBackground: ((Color) -> ())? = lib:get("ClearBackground", "void", ColorT)
assert(ClearBackground, "Failed to find ClearBackground")

local DrawText: ((string, number, number, number, ffi.StructureArg<Color>) -> ())? =
	lib:get("DrawText", "void", "pointer", "sint", "sint", "sint", ColorT)
assert(DrawText, "Failed to find DrawText")

return {
	CONFIG_FLAG = CONFIG_FLAG,
	SetConfigFlags = SetConfigFlags,
	InitWindow = InitWindow,
	SetTargetFPS = SetTargetFPS,
	CloseWindow = CloseWindow,
	WindowShouldClose = WindowShouldClose,
	BeginDrawing = BeginDrawing,
	EndDrawing = EndDrawing,
	ColorT = ColorT,
	DrawText = DrawText,
	ClearBackground = ClearBackground,
}
