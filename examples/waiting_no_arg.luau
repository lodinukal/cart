local task = require("@cart/task")

print("Waiting for as short as possible...")
local x = task.wait()
print("Done waiting!")
print(`Waited for {x} seconds.`)
