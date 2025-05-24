local task = {}

--- like coroutine.yield but resumes the thread later
function task.defer() end

return task
