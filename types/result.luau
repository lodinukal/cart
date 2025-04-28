local result = {}

export type Result<T, E> = | { read ok: true, read value: T } | { read ok: false, read why: E, read explanation: string? }

return result
