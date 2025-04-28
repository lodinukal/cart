local result = require("./result")

export type ReaderError = | "InvalidReader" | "ReadError" | "InvalidReaderResult"

export type WriterError = | "InvalidWriter" | "WriteError" | "InvalidWriterResult"

export type Error = | ReaderError | WriterError | "Unexpected"

export type Reader<T> = {
	--- tries to read buffer.len(into) bytes from the stream into the buffer and returns the number of bytes read or an error message
	read: (self: T, into: buffer) -> result.Result<number, Error>,
}

export type Writer<T> = {
	--- tries to write buffer.len(from) bytes from the buffer into the stream and returns the number of bytes written or an error message
	write: (self: T, from: buffer) -> result.Result<number, Error>,
}

return {}
