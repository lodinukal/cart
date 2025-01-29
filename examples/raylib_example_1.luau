local rl = require("./raylib")
local task = require("@cart/task")
local ffi = require("@cart/ffi")

local size = ffi.sizeof(rl.ColorT)
local cstack = buffer.create(size * 3)
rl.ColorT:write(cstack, size * 0, { r = 255, g = 255, b = 255, a = 255 })
rl.ColorT:write(cstack, size * 1, { r = 70, g = 255, b = 45, a = 255 })

local first_color = ffi.slice(cstack, size * 0, size)
local second_color = ffi.slice(cstack, size * 1, size)

print(`first_color_len: {first_color}`)

local total_time = 0

local text_options = {
	"apple",
	"banana",
	"cherry",
	"date",
	"elderberry",
	"fig",
}

rl.SetConfigFlags(rl.CONFIG_FLAG.WINDOW_RESIZABLE)
rl.InitWindow(300, 200, "Cart ffi test")
rl.SetTargetFPS(60)
while not rl.WindowShouldClose() do
	rl.BeginDrawing()
	rl.ClearBackground({ r = 12, g = 12, b = 12, a = 255 })
	local text = text_options[math.floor(total_time) % #text_options + 1]
	rl.DrawText(text, 10, 10, 20, first_color)
	total_time += task.wait(0.016)
	buffer.writeu8(cstack, 0, (math.sin(total_time) + 1) / 2 * 255)
	buffer.writeu8(cstack, 1, (math.sin(total_time + 0.4) + 1) / 2 * 255)
	buffer.writeu8(cstack, 2, (math.sin(total_time + 0.5) + 1) / 2 * 255)

	rl.DrawText("Hello from cart", 10, 30, 20, second_color)

	rl.EndDrawing()
end
rl.CloseWindow()
