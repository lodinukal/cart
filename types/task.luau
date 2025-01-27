local task = {}

function task.cancel(thread: thread)
	local _ = thread
	return
end

function task.defer<T...>(functionOrThread: thread | (T...) -> ...any, ...: T...): thread
	local _ = functionOrThread
	local _ = select("#", ...)
	return nil :: any
end

function task.delay<T...>(duration: number, functionOrThread: thread | (T...) -> ...any, ...: T...): thread
	local _ = duration
	local _ = functionOrThread
	local _ = select("#", ...)
	return nil :: any
end

function task.spawn<T...>(functionOrThread: thread | (T...) -> ...any, ...: T...): thread
	local _ = functionOrThread
	local _ = select("#", ...)
	return nil :: any
end

function task.wait(duration: number?): number
	local _ = duration
	return nil :: any
end

return task
