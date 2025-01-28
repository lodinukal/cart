local task = require("@cart/task")

print("Waiting for 5 seconds...")
local x = task.wait(5)
print("Done waiting!")
print(`Waited for {x} seconds.`)
