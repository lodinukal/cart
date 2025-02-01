--!strict

export type Error<T> = {
	--- Creates a new error
	init: (self: Error<T>, T) -> ErrorInstance<T>,
	--- Checks if the error is this kind, if it is then it returns the error, otherwise it returns nil
	as: (self: Error<T>, unknown) -> ErrorInstance<T>?,
}

export type ErrorInstance<T> = {
	get: (self: ErrorInstance<T>) -> T,
}

local result = {}

return result
