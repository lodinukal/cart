local net = {}

export type AddressFamily = "ipv4" | "ipv6"

--- address is either ipv4 or ipv6
function net.tcp(address_family: AddressFamily): Result<TCPStream, NetError>
	return nil :: any
end

--- accepts a standard RFC Uri and returns a list of addresses it corresponds to
function net.resolveaddress(uri: string): Result<{ { address: string, port: number } }, NetError>
	return nil :: any
end

return net
