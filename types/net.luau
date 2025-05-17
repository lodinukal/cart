local net = {}

export type AddressFamily = "ipv4" | "ipv6"
export type Protocol = "tcp" | "udp"

function net.socket(family: AddressFamily, protocol: Protocol): Result<Socket, NetError>
	return nil :: any
end

return net
