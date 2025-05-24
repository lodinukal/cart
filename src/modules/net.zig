const registry_index_key = "@cart/net";

pub const PerContextData = struct {
    pub fn init(_: *PerContextData, _: std.mem.Allocator) !void {}

    pub fn deinit(_: *PerContextData) void {}

    pub fn get(l: *luau.State) ?*PerContextData {
        if (l.getField(.registry, registry_index_key) != .userdata) {
            l.pop(1);
            return null;
        }
        defer l.pop(1);
        return @alignCast(@ptrCast(l.toUserdata(.at(-1)) orelse {
            return null;
        }));
    }
};

pub fn push(context: *cart.Context) !void {
    const l = context.state;
    const allocator = l.allocator();

    const data: *PerContextData = @alignCast(@ptrCast(l.newUserdataDtor(
        @sizeOf(PerContextData),
        @ptrCast(&PerContextData.deinit),
    ) orelse return error.OutOfMemory));
    try data.init(allocator);
    l.setField(.registry, registry_index_key);

    // TCPStream
    try l.newMetatable(tcp_stream_metatable);
    l.pushTable(.at(-1), .{
        .__type = tcp_stream_metatable,
        .__metatable = "This metatable is locked",
        // .__tostring = tcpStreamToString,
        .__index = .{
            .close = closeTcpStreamHandled,
            .bind = bindTcpStreamHandled,
            .settimeouts = setTcpStreamTimeoutsHandled,
            .connect = luau.vm.ClosureK.withContinuation(connectTcpStreamHandled, connectTcpStreamCont, "connect"),
            .listen = listenTcpStreamHandled,
            .accept = luau.vm.ClosureK.withContinuation(acceptTcpStreamHandled, acceptTcpStreamCont, "accept"),
            .send = luau.vm.ClosureK.withContinuation(sendTcpStreamHandled, sendTcpStreamCont, "send"),
            .receive = luau.vm.ClosureK.withContinuation(recvTcpStreamHandled, recvTcpStreamCont, "recv"),
            .getlocalendpoint = getLocalEndpointHandled,
            .getremoteendpoint = getRemoteEndpointHandled,
            .reader = reader,
            .writer = writer,
        },
    }, null);
    l.setReadonly(.at(-1), true);
    l.pop(1);

    l.createPushTable(.{
        .tcp = createTcpHandled,
        .resolveaddress = resolveAddressHandled,
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
    NotATCPStream,
    InvalidTCPStream,
    InvalidIPAddressFormat,
    OutOfMemory,
} || std.posix.SocketError || error{
    Overflow,
    InvalidCharacter,
} || xev.AcceptError ||
    xev.ReadError ||
    xev.WriteError ||
    std.posix.ListenError ||
    std.posix.BindError ||
    std.posix.SetSockOptError ||
    std.posix.GetSockNameError ||
    std.Uri.ParseError;

pub const YieldError = Error || error{YieldLuau1};

pub fn errorName(err: Error) []const u8 {
    return switch (err) {
        error.InvalidState => return "invalid program state",
        error.InvalidArgument => return "invalid argument",
        error.NotImplemented => return "not implemented",
        error.NotATCPStream => return "not a tcp stream",
        error.InvalidTCPStream => return "invalid tcp stream",
        error.OutOfMemory => return "out of memory",
        else => return @errorName(err),
    };
}

fn resolveAddressHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Index,
        resolveAddress(l, &diagnostics),
        &diagnostics,
    );
}

fn resolveAddress(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Index {
    // const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();

    const uri_str = l.toLengthString(.at(1));
    const uri: std.Uri = std.Uri.parse(uri_str) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Invalid uri `{s}` because {s}", .{ uri_str, errorName(err) }) catch {};
        }
        return err;
    };

    const host = (uri.host orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid uri `{s}` because missing host", .{uri_str}) catch {};
        }
        return error.InvalidArgument;
    });

    var buf: [512]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buf);

    const host_raw = host.toRawMaybeAlloc(fba.allocator()) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Invalid uri `{s}` because {s}", .{ uri_str, errorName(err) }) catch {};
        }
        return err;
    };

    const address_list = std.net.getAddressList(allocator, host_raw, uri.port orelse 80) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to resolve uri `{s}` because {s}", .{ uri_str, @errorName(err) }) catch {};
        }
        return error.Unexpected;
    };
    defer address_list.deinit();

    l.createTable(@intCast(address_list.addrs.len), 0);
    for (address_list.addrs, 1..) |address, i| {
        switch (address.any.family) {
            std.posix.AF.INET => {
                const bytes = @as(*const [4]u8, @ptrCast(&address.in.sa.addr));
                l.pushFmtString("{}.{}.{}.{}", .{
                    bytes[0],
                    bytes[1],
                    bytes[2],
                    bytes[3],
                }) catch continue;
            },
            std.posix.AF.INET6 => {
                var ipv6_buffer: [40]u8 = undefined;
                var ipv6_stream = std.io.fixedBufferStream(&ipv6_buffer);
                const ipwriter = ipv6_stream.writer();
                utilFmtJustIpv6Address(address, ipwriter) catch continue;
                l.pushLengthString(ipv6_stream.getWritten());
            },
            else => {
                if (diagnostics) |diag| {
                    diag.push("Invalid address `{}` because not ipv4 or ipv6", .{address}) catch {};
                }
                return error.InvalidIPAddressFormat;
            },
        }
        l.createPushTable(.{
            .address = luau.vm.Index.at(-1),
            .port = address.getPort(),
        }, null);
        l.remove(.at(-2));
        l.rawSeti(.at(-2), @intCast(i));
    }

    return .at(-1);
}

fn utilFmtJustIpv6Address(
    address: std.net.Address,
    ipwriter: anytype,
) !void {
    if (std.mem.eql(u8, address.in6.sa.addr[0..12], &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff })) {
        try std.fmt.format(ipwriter, "[::ffff:{}.{}.{}.{}]", .{
            address.in6.sa.addr[12],
            address.in6.sa.addr[13],
            address.in6.sa.addr[14],
            address.in6.sa.addr[15],
        });
        return;
    }
    const big_endian_parts = @as(*align(1) const [8]u16, @ptrCast(&address.in6.sa.addr));
    const native_endian_parts = switch (native_endian) {
        .big => big_endian_parts.*,
        .little => blk: {
            var endian_buffer: [8]u16 = undefined;
            for (big_endian_parts, 0..) |part, index| {
                endian_buffer[index] = std.mem.bigToNative(u16, part);
            }
            break :blk endian_buffer;
        },
    };

    // Find the longest zero run
    var longest_start: usize = 8;
    var longest_len: usize = 0;
    var current_start: usize = 0;
    var current_len: usize = 0;

    for (native_endian_parts, 0..) |part, index| {
        if (part == 0) {
            if (current_len == 0) {
                current_start = index;
            }
            current_len += 1;
            if (current_len > longest_len) {
                longest_start = current_start;
                longest_len = current_len;
            }
        } else {
            current_len = 0;
        }
    }

    // Only compress if the longest zero run is 2 or more
    if (longest_len < 2) {
        longest_start = 8;
        longest_len = 0;
    }

    try ipwriter.writeAll("[");
    var index: usize = 0;
    var abbrv = false;
    while (index < native_endian_parts.len) : (index += 1) {
        if (index == longest_start) {
            // Emit "::" for the longest zero run
            if (!abbrv) {
                try ipwriter.writeAll(if (index == 0) "::" else ":");
                abbrv = true;
            }
            index += longest_len - 1; // Skip the compressed range
            continue;
        }
        if (abbrv) {
            abbrv = false;
        }
        try std.fmt.format(ipwriter, "{x}", .{native_endian_parts[index]});
        if (index != native_endian_parts.len - 1) {
            try ipwriter.writeAll(":");
        }
    }
    try ipwriter.writeAll("]");
}

// tcp stream

pub const tcp_stream_metatable = "cart/net.TCPStream";
pub const TCP = struct {
    context: *cart.Context,
    completion: xev.Completion = undefined,

    ref: union(enum) { valid: luau.vm.Ref, dtor: luau.vm.Ref, dead },

    stream: xev.TCP,

    /// a field used only by connection streams, if not present, this is a
    /// regular stream
    connection: ?struct {
        remote_address: std.net.Address,
        local_address: std.net.Address,
    } = null,

    pub fn push(l: *luau.State, context: *cart.Context, stream: xev.TCP) !*TCP {
        const new_tcp: *TCP = @alignCast(@ptrCast(l.newUserdataDtor(
            @sizeOf(TCP),
            @ptrCast(&tcpDtor),
        ) orelse
            return error.OutOfMemory));
        const ref = l.ref(.at(-1));
        _ = l.getMetatableRegistry(tcp_stream_metatable);
        l.setMetatable(.at(-2));
        new_tcp.* = .{
            .context = context,
            .ref = .{ .valid = ref },
            .stream = stream,
        };
        return new_tcp;
    }

    pub fn to(l: *luau.State, at: luau.vm.Index) !*TCP {
        const tcp: *TCP = @alignCast(@ptrCast(l.checkUserdata(at, tcp_stream_metatable) orelse return error.NotATCPStream));
        if (tcp.ref != .valid) return error.InvalidTCPStream;
        return tcp;
    }
};

fn tcpDtor(tcp: *TCP) callconv(.c) void {
    if (tcp.ref == .valid) {
        tcp.ref = .{ .dtor = tcp.ref.valid };
        tcp.stream.close(&tcp.context.loop, &tcp.completion, TCP, tcp, (struct {
            fn callback(
                ud: ?*TCP,
                _: *xev.Loop,
                _: *xev.Completion,
                _: xev.TCP,
                r: xev.CloseError!void,
            ) xev.CallbackAction {
                _ = r catch return .disarm;
                // ud.?.valid = false;
                ud.?.context.state.unref(ud.?.ref.dtor);
                ud.?.ref = .dead;
                return .disarm;
            }
        }).callback);
    }
}

fn tcpStreamToString(l: *luau.State) Error!i32 {
    const tcp: *TCP = try .to(l, .at(1));
    _ = tcp;
    // const endpoint = tcp.stream.endpoint orelse {
    //     l.pushLengthString("cart/stream(unbound)");
    //     return 1;
    // };
    try l.pushFmtString("cart/stream", .{});
    return 1;
}

fn createTcpHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!luau.vm.Index,
        createTcp(l, &diagnostics),
        &diagnostics,
    );
}

// arg1: ip
// arg2: port
fn createTcp(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!luau.vm.Index {
    const context: *cart.Context = try .fromState(l);

    const family = std.meta.stringToEnum(enum { ipv4, ipv6 }, l.toLengthString(.at(1))) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid family `{s}`", .{cart.util.tostring(l, .at(1))}) catch {};
        }
        return error.InvalidArgument;
    };

    const address: std.net.Address = switch (family) {
        .ipv4 => .initIp4(@splat(0), 0),
        .ipv6 => .initIp6(@splat(0), 0, 0, 0),
    };

    const stream = try xev.TCP.init(address);

    const tcp = try TCP.push(l, context, stream);
    _ = tcp;
    return .at(-1);
}

fn closeTcpStreamHandled(l: *luau.State) i32 {
    return cart.util.returnValue(l, bool, closeTcpStream(l));
}

fn closeTcpStream(l: *luau.State) bool {
    const tcp: *TCP = TCP.to(l, .at(1)) catch return false;
    tcpDtor(tcp);
    return true;
}

// function close(self): boolean

fn bindTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        bindTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

fn bindTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const tcp: *TCP = try TCP.to(l, .at(1));

    const port = l.toIntegerx(.at(3)) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid port `{s}`", .{cart.util.tostring(l, .at(2))}) catch {};
        }
        return error.InvalidArgument;
    };

    const address = std.net.Address.parseIp(l.toLengthString(.at(2)), @intCast(port)) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Invalid address `{s}` because {s}", .{ l.toLengthString(.at(2)), errorName(err) }) catch {};
        }
        return err;
    };

    tcp.stream.bind(address) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to bind tcp stream because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn setTcpStreamTimeoutsHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        setTcpStreamTimeouts(l, &diagnostics),
        &diagnostics,
    );
}

fn setTcpStreamTimeouts(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const tcp: *TCP = try TCP.to(l, .at(1));
    const read_timeout: ?u32 = if (l.toIntegerx(.at(2))) |micros| @intCast(micros) else null;
    const write_timeout: ?u32 = if (l.toIntegerx(.at(3))) |micros| @intCast(micros) else null;

    const is_windows = builtin.os.tag == .windows;

    const fd = if (xev.backend == .iocp)
        @as(std.os.windows.ws2_32.SOCKET, @ptrCast(tcp.stream.fd))
    else
        tcp.stream.fd;

    if (read_timeout) |micros| {
        var opt = if (is_windows) @as(u32, @divTrunc(micros, 1000)) else std.posix.timeval{
            .sec = @intCast(@divTrunc(micros, std.time.us_per_s)),
            .usec = @intCast(@mod(micros, std.time.us_per_s)),
        };
        std.posix.setsockopt(
            fd,
            std.posix.SOL.SOCKET,
            std.posix.SO.RCVTIMEO,
            if (is_windows) std.mem.asBytes(&opt) else std.mem.toBytes(opt)[0..],
        ) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to set tcp stream read timeout because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };
    }
    if (write_timeout) |micros| {
        var opt = if (is_windows) @as(u32, @divTrunc(micros, 1000)) else std.posix.timeval{
            .tv_sec = @intCast(@divTrunc(micros, std.time.us_per_s)),
            .tv_usec = @intCast(@mod(micros, std.time.us_per_s)),
        };
        std.posix.setsockopt(
            fd,
            std.posix.SOL.SOCKET,
            std.posix.SO.SNDTIMEO,
            if (is_windows) std.mem.asBytes(&opt) else std.mem.toBytes(opt)[0..],
        ) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to set tcp stream write timeout because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };
    }
}

const ConnectTCPAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    diagnostics: cart.util.Diagnostics = .{},

    result: xev.ConnectError!void = undefined,

    pub fn callback(
        opt_self: ?*ConnectTCPAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.TCP,
        r: xev.ConnectError!void,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.result = r;
        if (r) |good| {
            _ = good;
        } else |err| {
            self.diagnostics.push("Failed to connect tcp stream because {s}", .{errorName(err)}) catch {};
        }
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn connectTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!void,
        connectTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

fn connectTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!void {
    const context: *cart.Context = try .fromState(l);

    const tcp: *TCP = try TCP.to(l, .at(1));
    const port = l.toIntegerx(.at(3)) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid port `{s}`", .{cart.util.tostring(l, .at(2))}) catch {};
        }
        return error.InvalidArgument;
    };

    const address = std.net.Address.parseIp(l.toLengthString(.at(2)), @intCast(port)) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Invalid address `{s}` because {s}", .{ l.toLengthString(.at(2)), errorName(err) }) catch {};
        }
        return err;
    };

    const allocator = l.allocator();
    const future = allocator.create(ConnectTCPAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
    };
    future.diagnostics.init();

    tcp.stream.connect(
        &context.loop,
        &future.completion,
        address,
        ConnectTCPAsync,
        future,
        &ConnectTCPAsync.callback,
    );

    return error.YieldLuau1;
}

fn connectTcpStreamCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *ConnectTCPAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    _ = status;
    if (future.result) |_| {
        cart.util.pushOk(l, void, {}, 0);
    } else |bad| {
        cart.util.pushError(l, @errorName(bad), &future.diagnostics, null);
    }
    return 1;
}

fn listenTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        Error!void,
        listenTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

fn listenTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) Error!void {
    const tcp: *TCP = try TCP.to(l, .at(1));

    const backlog = l.toIntegerx(.at(2)) orelse {
        if (diagnostics) |diag| {
            diag.push("Invalid backlog `{s}`", .{cart.util.tostring(l, .at(2))}) catch {};
        }
        return error.InvalidArgument;
    };

    tcp.stream.listen(@intCast(backlog)) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to listen on tcp stream because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
}

fn acceptTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Index,
        acceptTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

const AcceptTCPAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    diagnostics: cart.util.Diagnostics = .{},

    local_address: std.net.Address = undefined,
    remote_address: std.net.Address = undefined,
    out_stream: xev.AcceptError!xev.TCP = undefined,

    pub fn callback(
        opt_self: ?*AcceptTCPAsync,
        _: *xev.Loop,
        c: *xev.Completion,
        r: xev.AcceptError!xev.TCP,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.out_stream = r;
        if (r) |good| {
            // IOCP is the only backend in which that this is not done for us by accept.
            // other backends will do this for us, except wasi_poll but cart net wont support that.
            switch (comptime xev.Backend.default()) {
                .iocp => {
                    var local_sockaddr: *std.posix.sockaddr = undefined;
                    var remote_sockaddr: *std.posix.sockaddr = undefined;
                    var local_sockaddr_len: i32 = 0;
                    var remote_sockaddr_len: i32 = 0;
                    // note the first 4 arguments are determined by libxev's usage of AcceptEx, we had to fork
                    // to get the local address name also being passed in.
                    std.os.windows.ws2_32.GetAcceptExSockaddrs(
                        &c.op.accept.storage,
                        0,
                        @as(u32, @intCast(@sizeOf(std.posix.sockaddr.storage))),
                        @as(u32, @intCast(@sizeOf(std.posix.sockaddr.storage))),
                        &local_sockaddr,
                        &local_sockaddr_len,
                        &remote_sockaddr,
                        &remote_sockaddr_len,
                    );

                    self.local_address.any = local_sockaddr.*;
                    self.remote_address.any = remote_sockaddr.*;
                },
                .wasi_poll => {
                    // wasi_poll does not support this
                    self.local_address = .initIp4(.{ 0, 0, 0, 0 }, 0);
                    self.remote_address = .initIp4(.{ 0, 0, 0, 0 }, 0);
                },
                else => {
                    // get local address using getsockname
                    self.local_address = .initIp4(.{ 0, 0, 0, 0 }, 0);
                    var sock_len = self.local_address.getOsSockLen();
                    std.posix.getsockname(
                        good.fd,
                        &self.local_address.any,
                        &sock_len,
                    ) catch |err| {
                        self.diagnostics.push("Failed to get local address because {s}", .{errorName(err)}) catch {};
                    };

                    // posix accept gives us peer address
                    self.remote_address.any = c.op.accept.addr;
                },
            }
        } else |err| {
            self.diagnostics.push("Failed to accept tcp stream because {s}", .{errorName(err)}) catch {};
        }
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn acceptTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Index {
    const context: *cart.Context = try .fromState(l);
    const allocator = l.allocator();
    const tcp: *TCP = try TCP.to(l, .at(1));

    const future = allocator.create(AcceptTCPAsync) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
    future.* = .{
        .allocator = allocator,
        .completion = undefined,
        .context = context,
        .l = l,
    };
    future.diagnostics.init();

    tcp.stream.accept(
        &context.loop,
        &future.completion,
        AcceptTCPAsync,
        future,
        &AcceptTCPAsync.callback,
    );

    return error.YieldLuau1;
}

fn acceptTcpStreamCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *AcceptTCPAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    _ = status;
    if (future.out_stream) |good| {
        const tcp = TCP.push(l, future.context, good) catch unreachable;
        tcp.connection = .{
            .remote_address = future.remote_address,
            .local_address = future.local_address,
        };
        cart.util.pushOk(l, luau.vm.Index, .at(-1), 0);
    } else |bad| {
        cart.util.pushError(l, @errorName(bad), &future.diagnostics, null);
    }
    return 1;
}

const SendTCPAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    diagnostics: cart.util.Diagnostics = .{},

    result: xev.WriteError!usize = undefined,
    buffer_ref: luau.vm.Ref = .no,

    pub fn callback(
        opt_self: ?*SendTCPAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.TCP,
        _: xev.WriteBuffer,
        r: xev.WriteError!usize,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.result = r;
        _ = r catch |err| {
            self.diagnostics.push("Failed to send tcp stream because {s}", .{errorName(err)}) catch {};
        };
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn sendTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Integer,
        sendTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

fn sendTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Integer {
    const tcp: *TCP = try TCP.to(l, .at(1));
    const buffer = l.toBuffer(.at(2));
    const max_bytes: i65 = l.toIntegerx(.at(3)) orelse std.math.maxInt(u32);

    const ref = l.ref(.at(2));

    return sendTcpStreamImpl(
        l,
        tcp,
        buffer,
        max_bytes,
        ref,
        diagnostics,
    );
}

fn tcpStreamWriteHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Integer,
        sendTcpStreamInnerWriter(l, &diagnostics),
        &diagnostics,
    );
}

fn sendTcpStreamInnerWriter(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Integer {
    if (l.type(.at(1)) != .table) {
        if (diagnostics) |diag| {
            diag.push("Invalid writer `{s}`", .{cart.util.tostring(l, .at(1))}) catch {};
        }
        return error.InvalidArgument;
    }

    if (l.getField(.at(1), "tcp") != .userdata) {
        if (diagnostics) |diag| {
            diag.push("Invalid reader `{s}`", .{cart.util.tostring(l, .at(1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const tcp: *TCP = @alignCast(@ptrCast(l.toUserdata(.at(-1)) orelse return error.InvalidArgument));
    l.pop(1);

    const buffer = l.toBuffer(.at(2));
    const ref = l.ref(.at(2));

    const max_bytes: i65 = l.toIntegerx(.at(3)) orelse std.math.maxInt(u32);

    return sendTcpStreamImpl(
        l,
        tcp,
        buffer,
        max_bytes,
        ref,
        diagnostics,
    );
}

fn sendTcpStreamImpl(
    l: *luau.State,
    tcp: *TCP,
    buffer: luau.vm.Buffer,
    max_bytes: i65,
    ref: luau.vm.Ref,
    diagnostics: ?*cart.util.Diagnostics,
) YieldError!luau.vm.Integer {
    {
        errdefer if (ref != .no) {
            l.unref(ref);
        };

        const old_slice = buffer.constSlice();
        const bytes: usize = if (max_bytes > old_slice.len) old_slice.len else @intCast(max_bytes);
        if (bytes == 0) {
            l.unref(ref);
            return 0;
        }

        const future = l.allocator().create(SendTCPAsync) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };

        future.* = .{
            .allocator = l.allocator(),
            .completion = undefined,
            .context = tcp.context,
            .l = l,
            .buffer_ref = ref,
        };
        future.diagnostics.init();

        tcp.stream.write(
            &tcp.context.loop,
            &future.completion,
            .{ .slice = old_slice[0..bytes] },
            SendTCPAsync,
            future,
            &SendTCPAsync.callback,
        );
    }

    return error.YieldLuau1;
}

fn sendTcpStreamCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *SendTCPAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    defer if (future.buffer_ref != .no) {
        future.l.unref(future.buffer_ref);
    };
    _ = status;
    cart.util.pushErrorUnion(l, YieldError!usize, future.result, &future.diagnostics);
    return 1;
}

const ReceiveTCPAsync = struct {
    allocator: std.mem.Allocator,
    completion: xev.Completion,

    context: *cart.Context,
    l: *luau.State,

    diagnostics: cart.util.Diagnostics = .{},

    buffer_ref: luau.vm.Ref = .no,
    result: xev.ReadError!usize = undefined,

    pub fn callback(
        opt_self: ?*ReceiveTCPAsync,
        _: *xev.Loop,
        _: *xev.Completion,
        _: xev.TCP,
        _: xev.ReadBuffer,
        r: xev.ReadError!usize,
    ) xev.CallbackAction {
        const self = opt_self orelse unreachable;
        self.result = r;
        _ = r catch |err| {
            self.diagnostics.push("Failed to receive tcp stream because {s}", .{errorName(err)}) catch {};
        };
        self.l.pushLightUserdata(@ptrCast(self));
        _ = self.l.@"resume"(null, 1);
        return .disarm;
    }
};

fn recvTcpStreamHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Index,
        recvTcpStream(l, &diagnostics),
        &diagnostics,
    );
}

fn recvTcpStream(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Index {
    const tcp: *TCP = try TCP.to(l, .at(1));
    const buffer = l.toBuffer(.at(2));

    const ref = l.ref(.at(2));

    return recvTcpStreamImpl(l, tcp, buffer, ref, diagnostics);
}

fn tcpStreamReadHandled(l: *luau.State) i32 {
    var diagnostics: cart.util.Diagnostics = undefined;
    diagnostics.init();
    return cart.util.returnErrorUnion(
        l,
        YieldError!luau.vm.Index,
        sendTcpStreamInnerReader(l, &diagnostics),
        &diagnostics,
    );
}

fn sendTcpStreamInnerReader(l: *luau.State, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Index {
    if (l.type(.at(1)) != .table) {
        if (diagnostics) |diag| {
            diag.push("Invalid reader `{s}`", .{cart.util.tostring(l, .at(1))}) catch {};
        }
        return error.InvalidArgument;
    }

    if (l.getField(.at(1), "tcp") != .userdata) {
        if (diagnostics) |diag| {
            diag.push("Invalid reader `{s}`", .{cart.util.tostring(l, .at(1))}) catch {};
        }
        return error.InvalidArgument;
    }
    const tcp: *TCP = @alignCast(@ptrCast(l.toUserdata(.at(-1)) orelse return error.InvalidArgument));
    l.pop(1);

    const buffer = l.toBuffer(.at(2));
    const ref = l.ref(.at(2));

    return recvTcpStreamImpl(
        l,
        tcp,
        buffer,
        ref,
        diagnostics,
    );
}

fn recvTcpStreamImpl(l: *luau.State, tcp: *TCP, buffer: luau.vm.Buffer, ref: luau.vm.Ref, diagnostics: ?*cart.util.Diagnostics) YieldError!luau.vm.Index {
    const allocator = l.allocator();
    {
        errdefer if (ref != .no) {
            l.unref(ref);
        };
        const future = allocator.create(ReceiveTCPAsync) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to create future because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };

        future.* = .{
            .allocator = allocator,
            .completion = undefined,
            .context = tcp.context,
            .l = l,
            .buffer_ref = ref,
        };
        future.diagnostics.init();

        tcp.stream.read(
            &tcp.context.loop,
            &future.completion,
            .{ .slice = buffer.mutable },
            ReceiveTCPAsync,
            future,
            &ReceiveTCPAsync.callback,
        );
    }
    return error.YieldLuau1;
}

fn recvTcpStreamCont(l: *luau.State, status: luau.vm.Status) callconv(.c) i32 {
    const future: *ReceiveTCPAsync = @alignCast(@ptrCast(l.toLightUserdata(.at(-1)) orelse return 0));
    defer future.allocator.destroy(future);
    defer if (future.buffer_ref != .no) {
        future.l.unref(future.buffer_ref);
    };
    _ = status;
    cart.util.pushErrorUnion(l, YieldError!usize, future.result, &future.diagnostics);
    return 1;
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
    const tcp: *TCP = try TCP.to(l, .at(1));

    if (tcp.connection) |conn| {
        l.pushFmtString("{}", .{conn.local_address}) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to format local endpoint because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };
        return .at(-1);
    }

    const fd = if (xev.backend == .iocp)
        @as(std.os.windows.ws2_32.SOCKET, @ptrCast(tcp.stream.fd))
    else
        tcp.stream.fd;

    var address: std.net.Address = .initIp4(.{ 0, 0, 0, 0 }, 0);
    var sock_len = address.getOsSockLen();
    std.posix.getsockname(fd, &address.any, &sock_len) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to get local endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    l.pushFmtString("{}", .{address}) catch |err| {
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
    const tcp: *TCP = try TCP.to(l, .at(1));

    if (tcp.connection) |conn| {
        l.pushFmtString("{}", .{conn.remote_address}) catch |err| {
            if (diagnostics) |diag| {
                diag.push("Failed to format local endpoint because {s}", .{errorName(err)}) catch {};
            }
            return err;
        };
        return .at(-1);
    }

    const fd = if (xev.backend == .iocp)
        @as(std.os.windows.ws2_32.SOCKET, @ptrCast(tcp.stream.fd))
    else
        tcp.stream.fd;

    var address: std.net.Address = .initIp4(.{ 0, 0, 0, 0 }, 0);
    var sock_len = address.getOsSockLen();
    std.posix.getpeername(fd, &address.any, &sock_len) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to get local endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };

    l.pushFmtString("{}", .{address}) catch |err| {
        if (diagnostics) |diag| {
            diag.push("Failed to format local endpoint because {s}", .{errorName(err)}) catch {};
        }
        return err;
    };
    return .at(-1);
}

fn reader(l: *luau.State) !i32 {
    const tcp: *TCP = TCP.to(l, .at(1)) catch return error.InvalidArgument;
    _ = tcp;

    l.createPushTable(.{
        .tcp = luau.vm.Index.at(1),
        .read = luau.vm.ClosureK.withContinuation(tcpStreamReadHandled, recvTcpStreamCont, "read"),
    }, null);
    return 1;
}

fn writer(l: *luau.State) !i32 {
    const tcp: *TCP = TCP.to(l, .at(1)) catch return error.InvalidArgument;
    _ = tcp;

    l.createPushTable(.{
        .tcp = luau.vm.Index.at(1),
        // .write = impl.write,
        .write = luau.vm.ClosureK.withContinuation(tcpStreamWriteHandled, sendTcpStreamCont, "write"),
    }, null);
    return 1;
}

const std = @import("std");
const builtin = @import("builtin");
const cart = @import("../root.zig");

const luau = cart.luau;
const util = cart.util;

const xev = @import("xev");

const native_endian = builtin.target.cpu.arch.endian();
