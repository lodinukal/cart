local result = {}

export type Result<T, E> = | { ok: true, value: T } | { ok: false, why: E, explanation: string? }

return result
