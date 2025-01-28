local rl = require("./raylib")
local task = require("@cart/task")

rl.SetConfigFlags(rl.CONFIG_FLAG.WINDOW_RESIZABLE)
rl.InitWindow(800, 600, "Hello, World!")
rl.SetTargetFPS(60)
while not rl.WindowShouldClose() do
	rl.BeginDrawing()
	rl.ClearBackground({ r = 16, g = 16, b = 16, a = 255 })
	rl.DrawText("Hello, World!", 10, 10, 20, { r = 255, g = 255, b = 255, a = 255 })
	task.wait(0.016)
	rl.EndDrawing()
end
rl.CloseWindow()
