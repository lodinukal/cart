pub fn push(context: *cart.Context) !void {
    const l = context.state;

    // Socket
    try l.newMetatable(socket_metatable);
    l.pushTable(.at(-1), .{
        .__type = socket_metatable,
        .__metatable = "This metatable is locked",
        .__tostring = socketToString,
        .__index = .{
            .close = closeSocketHandled,
            .bind = bindSocketHandled,
            .settimeouts = closeSocketHandled,
            .setbroadcast = setSocketBroadcastHandled,
            .connect = connectSocketHandled,
            .listen = listenSocketHandled,
            .accept = acceptSocketHandled,
            .send = sendSocketHandled,
            .peek = sendSocketHandled,
            .receive = recvSocketHandled,
            .sendto = sendSocketHandled,
            .enableportreuse = setSocketReuseHandled,
            .getlocalendpoint = getLocalEndpointHandled,
            .getremoteendpoint = getRemoteEndpointHandled,
            .joinmulticastgroup = joinMulticastGroupHandled,
            .reader = reader,
            .writer = writer,
        },
    }, null);
    l.setReadonly(.at(-1), true);
    l.pop(1);

    l.createPushTable(.{
        .socket = createSocketHandled,
    }, null);
    l.setReadonly(.at(-1), true);
}

pub fn open(context: *cart.Context) !void {
    context.state.pushLengthString("@cart/net");
    try push(context);
    luau.require.registermodule(context.state);
}

pub const Error = error{
    InvalidState,
    InvalidArgument,
    NotImplemented,
    NotASocket,
    InvalidSocket,
    OutOfMemory,
} || std.posix.SocketError || error{
    Overflow,
    InvalidCharacter,
} || std.posix.SetSockOptError ||
    std.posix.GetSockNameError ||
    std.posix.AcceptError ||
    std.posix.BindError ||
    std.posix.ConnectError ||
    network.Socket.ReceiveError ||
    network.Socket.SendError || error{
    UnsupportedAddressFamily,
    InsufficientBytes,
    InvalidFormat,
    AddressInUse,
    AddressFamilyMismatch,
};

pub fn errorName(err: Error) []const u8 {
    return switch (err) {
        error.InvalidState => return "invalid program state",
        error.InvalidArgument => return "invalid argument",
        error.NotImplemented => return "not implemented",
        error.NotASocket => return "not a socket",
        error.InvalidSocket => return "invalid socket",
        error.OutOfMemory => return "out of memory",

        // std.posix.SocketError
        error.AccessDenied => return "access denied",
        error.SystemResources => return "system resources exhausted",
        error.ProcessFdQuotaExceeded => return "process file descriptor quota exceeded",
        error.SystemFdQuotaExceeded => return "system file descriptor quota exceeded",
        error.Unexpected => return "unexpected error",
        error.AddressFamilyNotSupported => return "address family not supported",
        error.ProtocolFamilyNotAvailable => return "protocol family not available",
        error.ProtocolNotSupported => return "protocol not supported",
        error.SocketTypeNotSupported => return "socket type not supported",

        // ip parsing
        error.Overflow => return "overflow",
        error.InvalidCharacter => return "invalid character",

        // std.posix.SetSockOptError
        error.AlreadyConnected => return "already connected",
        error.InvalidProtocolOption => return "invalid protocol option",
        error.TimeoutTooBig => return "timeout too big",
        error.PermissionDenied => return "permission denied",
        error.OperationNotSupported => return "operation not supported",
        error.NetworkSubsystemFailed => return "network subsystem failed",
        error.FileDescriptorNotASocket => return "file descriptor not a socket",
        error.SocketNotBound => return "socket not bound",
        error.NoDevice => return "no device",

        // std.posix.GetSockNameError
        // already handled

        // network.Socket.ReceiveError
        error.WouldBlock => return "would block",
        error.ConnectionRefused => return "connection refused",
        error.ConnectionResetByPeer => return "connection reset by peer",
        error.ConnectionTimedOut => return "connection timed out",
        error.MessageTooBig => return "message too big",
        error.SocketNotConnected => return "socket not connected",

        else => return "unknown error",
    };
}

// socket

pub const socket_metatable = "cart/net/socket";
pub const Socket = struct {
    allocator: std.mem.Allocator,
    valid: bool = true,

    socket: network.Socket,
    protocol: Protocol,

    pub const AddressFamily = network.AddressFamily;
    pub const Protocol = network.Protocol;

    pub fn push(l: *luau.State, socket: network.Socket, protocol: Protocol) !*Socket {
        const allocator = l.allocator();
        const new_socket: *Socket = @alignCast(@ptrCast(l.newUserdataDtor(
            @sizeOf(Socket),
            @ptrCast(&socketDtor),
        ) orelse
            return error.OutOfMemory));
        _ = l.getMetatableRegistry(socket_metatable);
        l.setMetatable(.at(-2));
        new_socket.* = .{
            .allocator = allocator,
            .valid = true,
            .socket = socket,
            .protocol = protocol,
        };
        return new_socket;
    }

    pub fn to(l: *luau.State, at: luau.vm.Index) !*Socket {
        const socket: *Socket = @alignCast(@ptrCast(l.checkUserdata(at, socket_metatable) orelse return error.NotASocket));
        if (!socket.valid) return error.InvalidSocket;
        return socket;
    }
};

fn socketDtor(socket: *Socket) callconv(.c) void {
    if (socket.valid) {
        socket.socket.close();
        socket.valid = false;
    }
}

fn socketToString(l: *luau.State) Error!i32 {
    const socket: *Socket = try .to(l, .at(1));
    const endpoint = socket.socket.endpoint orelse {
        l.pushLengthString("cart/socket(unbound)");
        return 1;
    };
    try l.pushFmtString("cart/socket({s}:{d})", .{ endpoint.address, endpoint.port });
    return 1;
}

fn createSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        createSocket(l, &diagnostics),
        &diagnostics,
    );
}

// arg1: family
// arg2: protocol
fn createSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const context: *cart.Context = try .fromState(l);
    _ = context;

    const family = std.meta.stringToEnum(Socket.AddressFamily, l.toLengthString(.at(1))) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid address family `{s}`", .{l.toLengthString(.at(1))}) catch {};
        }
        return error.InvalidArgument;
    };
    const protocol = std.meta.stringToEnum(Socket.Protocol, l.toLengthString(.at(2))) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid protocol `{s}`", .{l.toLengthString(.at(2))}) catch {};
        }
        return error.InvalidArgument;
    };

    const socket = network.Socket.create(family, protocol) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    const socket_obj = try Socket.push(l, socket, protocol);
    _ = socket_obj;
    return .at(-1);
}

fn closeSocketHandled(l: *luau.State) i32 {
    return cart.util.returnValue(l, bool, closeSocket(l));
}

fn closeSocket(l: *luau.State) bool {
    const socket: *Socket = Socket.to(l, .at(1)) catch return false;
    socketDtor(socket);
    return true;
}

// function close(self): boolean

fn bindSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        bindSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn bindSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const endpoint: network.EndPoint = try .parse(l.toLengthString(.at(2)));

    socket.socket.bind(endpoint) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to bind socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn setSocketTimeoutsHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        setSocketTimeouts(l, &diagnostics),
        &diagnostics,
    );
}

fn setSocketTimeouts(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const read_timeout = l.toIntegerx(.at(2));
    const write_timeout = l.toIntegerx(.at(3));

    socket.socket.setTimeouts(if (read_timeout) |t| @intCast(t) else null, if (write_timeout) |t| @intCast(t) else null) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to set socket timeouts because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn setSocketBroadcastHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        setSocketBroadcast(l, &diagnostics),
        &diagnostics,
    );
}

fn setSocketBroadcast(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const enable = l.toBoolean(.at(2));

    socket.socket.setBroadcast(enable) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to set socket broadcast because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn connectSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        connectSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn connectSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const endpoint: network.EndPoint = try .parse(l.toLengthString(.at(2)));

    socket.socket.connect(endpoint) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to connect socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn listenSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        listenSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn listenSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));

    socket.socket.listen() catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to listen on socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn acceptSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        acceptSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn acceptSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const socket: *Socket = try Socket.to(l, .at(1));

    const new_socket = socket.socket.accept() catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to accept socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    const new_socket_obj = try Socket.push(l, new_socket, socket.protocol);
    _ = new_socket_obj;
    return .at(-1);
}

fn sendSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Integer,
        sendSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn sendSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Integer {
    const socket: *Socket = try Socket.to(l, .at(1));
    const buffer = l.toBuffer(.at(2));
    const max_bytes: i65 = l.toIntegerx(.at(3)) orelse std.math.maxInt(u32);

    return sendSocketImpl(
        l,
        socket,
        buffer,
        max_bytes,
        diagnostics,
    );
}

fn sendSocketImpl(
    l: *luau.State,
    socket: *Socket,
    buffer: luau.vm.Buffer,
    max_bytes: i65,
    diagnostics: ?*cart.util.Diagnostics,
) Error!luau.vm.Integer {
    _ = l;
    const old_slice = buffer.constSlice();
    const bytes: usize = if (max_bytes > old_slice.len) old_slice.len else @intCast(max_bytes);
    if (bytes == 0) {
        return 0;
    }

    const bytes_sent = socket.socket.send(old_slice[0..bytes]) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to send socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    return @intCast(bytes_sent);
}

fn peekSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Integer,
        peekSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn peekSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Integer {
    const socket: *Socket = try Socket.to(l, .at(1));
    const buffer = l.toBuffer(.at(2));

    const bytes_peeked = socket.socket.peek(buffer.mutable) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to peek socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    return @intCast(bytes_peeked);
}

fn recvSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        recvSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn recvSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const socket: *Socket = try Socket.to(l, .at(1));
    const buffer = l.toBuffer(.at(2));

    return recvSocketImpl(l, socket, buffer, diagnostics);
}

fn recvSocketImpl(l: *luau.State, socket: *Socket, buffer: luau.vm.Buffer, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const allocator = l.allocator();
    switch (socket.protocol) {
        .tcp => {
            const bytes_recv = socket.socket.receive(buffer.mutable) catch |err| {
                if (diagnostics) |diag| {
                    diag.push("Failed to recv socket because {s}", .{errorName(err)}) catch {};
                }
                return err;
            };
            l.createPushTable(.{
                .length = bytes_recv,
                .sender = @as(void, {}),
            }, null);
            return .at(-1);
        },
        .udp => {
            const bytes_recv = socket.socket.receiveFrom(buffer.mutable) catch |err| {
                if (diagnostics) |diag| {
                    diag.push("Failed to recv socket because {s}", .{errorName(err)}) catch {};
                }
                return err;
            };
            const sender = std.fmt.allocPrint(allocator, "{s}", .{bytes_recv.sender}) catch |err| {
                if (diagnostics) |diag| {
                    diag.push("Failed to format sender address because {s}", .{errorName(err)}) catch {};
                }
                return err;
            };
            defer allocator.free(sender);
            l.createPushTable(.{
                .length = bytes_recv.numberOfBytes,
                .sender = sender,
            }, null);
            return .at(-1);
        },
    }
}

fn sendtoSocketHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Integer,
        sendtoSocket(l, &diagnostics),
        &diagnostics,
    );
}

fn sendtoSocket(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Integer {
    const socket: *Socket = try Socket.to(l, .at(1));
    const endpoint: network.EndPoint = try .parse(l.toLengthString(.at(2)));
    const buffer = l.toBuffer(.at(3));

    const bytes_sent = socket.socket.sendTo(endpoint, buffer.constSlice()) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to sendto socket because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    return @intCast(bytes_sent);
}

fn setSocketReuseHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        setSocketReuse(l, &diagnostics),
        &diagnostics,
    );
}

fn setSocketReuse(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const enable = l.toBoolean(.at(2));

    socket.socket.enablePortReuse(enable) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to set socket port reuse because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn getLocalEndpointHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        getLocalEndpoint(l, &diagnostics),
        &diagnostics,
    );
}

fn getLocalEndpoint(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const socket: *Socket = try Socket.to(l, .at(1));

    const endpoint = socket.socket.getLocalEndPoint() catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to get local endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    l.pushFmtString("{s}", .{endpoint}) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to format local endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
    return .at(-1);
}

fn getRemoteEndpointHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        getRemoteEndpoint(l, &diagnostics),
        &diagnostics,
    );
}

fn getRemoteEndpoint(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const socket: *Socket = try Socket.to(l, .at(1));

    const endpoint = socket.socket.getRemoteEndPoint() catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to get remote endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    l.pushFmtString("{s}", .{endpoint}) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to format remote endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
    return .at(-1);
}

fn joinMulticastGroupHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        joinMulticastGroup(l, &diagnostics),
        &diagnostics,
    );
}

fn joinMulticastGroup(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const socket: *Socket = try Socket.to(l, .at(1));
    const interface = l.toLengthString(.at(2));
    const group = l.toLengthString(.at(3));

    socket.socket.joinMulticastGroup(.{
        .interface = network.Address.IPv4.parse(interface) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to parse interface `{s}` because {s}", .{ interface, errorName(err) }) catch {};
            }
            return err;
        },
        .group = network.Address.IPv4.parse(group) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to parse group `{s}` because {s}", .{ group, errorName(err) }) catch {};
            }
            return err;
        },
    }) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to join multicast group because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn reader(l: *luau.State) !i32 {
    const socket: *Socket = Socket.to(l, .at(1)) catch return error.InvalidArgument;
    _ = socket;

    l.createPushTable(.{
        .socket = luau.vm.Index.at(1),
        .read = impl.read,
    }, null);
    return 1;
}

fn writer(l: *luau.State) !i32 {
    const socket: *Socket = Socket.to(l, .at(1)) catch return error.InvalidArgument;
    _ = socket;

    l.createPushTable(.{
        .socket = luau.vm.Index.at(1),
        .write = impl.write,
    }, null);
    return 1;
}

const impl = struct {
    pub fn read(l: *luau.State) !i32 {
        if (l.type(.at(1)) != .table) {
            l.pop(1);
            return error.InvalidArgument;
        }

        if (l.getField(.at(1), "socket") != .userdata) {
            l.pop(1);
            return error.InvalidArgument;
        }
        const socket: *Socket = try Socket.to(l, .at(-1));
        const buffer = l.toBuffer(.at(2));

        var diagnostics: cart.util.Diagnostics = undefined;
        diagnostics.init();

        cart.util.pushErrorUnion(
            l,
            Error!luau.vm.Index,
            recvSocketImpl(l, socket, buffer, &diagnostics),
            &diagnostics,
        );

        // get the length from the top of the stack
        if (l.getField(.at(-2), "length") != .number) {
            l.pop(1);
            return error.InvalidArgument;
        }
        l.remove(.at(-2));
        l.remove(.at(-2));
        cart.util.pushOk(l, luau.vm.Integer, l.toIntegerx(.at(-1)) orelse 0, null);
        return 1;
    }

    pub fn write(l: *luau.State) !i32 {
        if (l.type(.at(1)) != .table) {
            l.pop(1);
            return error.InvalidArgument;
        }

        if (l.getField(.at(1), "socket") != .userdata) {
            l.pop(1);
            return error.InvalidArgument;
        }
        const socket: *Socket = try Socket.to(l, .at(-1));
        const buffer = l.toBuffer(.at(2));
        const max_bytes: i65 = l.toIntegerx(.at(3)) orelse std.math.maxInt(u32);

        var diagnostics: cart.util.Diagnostics = undefined;
        diagnostics.init();

        return cart.util.returnErrorUnion(
            l,
            Error!luau.vm.Integer,
            sendSocketImpl(l, socket, buffer, max_bytes, &diagnostics),
            &diagnostics,
        );
    }
};

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");
const luau = cart.luau;

const util = cart.util;

const network = @import("network");
