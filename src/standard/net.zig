pub const FetchContext = struct {
    allocator: std.mem.Allocator,
    request: Platform.Request,
    server_header_buffer: []u8,

    /// passed into reader push as pushing in pointers is a bit hairy
    pub const Wrap = struct {
        context: ?*FetchContext = null,

        pub fn deinit(self: *Wrap) void {
            if (self.context) |context| context.deinit();
            self.context = null;
        }
    };

    pub fn deinit(self: *FetchContext) void {
        self.allocator.free(self.server_header_buffer);
        self.request.destroy();
        self.allocator.destroy(self);
    }

    pub fn poll(context: *FetchContext, thread: *const Scheduler.Thread, _: *Context) Scheduler.Poll {
        switch (context.request.status()) {
            .pending => return .pending,
            .ready => |reader| {
                const r = io.LReader.push(thread.state, Wrap) catch @panic("failed to push reader");
                r.reader = reader;
                const rctx = r.erased.as(Wrap);
                rctx.context = context;
                r.reader = reader;
            },
            .err => |err| {
                thread.state.pushString(@errorName(err));
                context.deinit();
            },
        }

        return .ready(1);
    }
};

threadlocal var global_client: ?Platform.HttpClient = null;
/// per thread client
pub fn setClient(client: ?Platform.HttpClient) void {
    global_client = client;
}

pub fn open(l: *luau.Luau) void {
    l.newTable();

    l.pushString("fetch");
    util.pushFunction(l, lFetch, "@cart/net.fetch");
    l.setTable(-3);

    l.setReadOnly(-1, true);
}

// 1: string url
// 2: FetchOptions options
fn lFetch(l: *luau.Luau) !i32 {
    const client = (global_client orelse (l.raiseErrorFmt("client not set", .{}) catch unreachable));
    const context = Context.getContext(l) orelse return 0;
    const url = l.toString(1) catch l.argError(1, "expected url");

    const lallocator = l.allocator();
    const t = context.temp.allocator();
    const options = parseFetchOptions(l, 2, t) catch |err| switch (err) {
        error.InvalidMethod => l.argError(2, "invalid method"),
        error.InvalidHeaderKey => l.argError(2, "invalid header key"),
        error.InvalidHeaderValue => l.argError(2, "invalid header value"),
        error.InvalidBody => l.argError(2, "invalid body"),
        else => return err,
    };

    const server_header_buffer = try lallocator.alloc(u8, 8 * 1024 * 4);

    const request_options: std.http.Client.RequestOptions = .{
        .server_header_buffer = server_header_buffer,
        .headers = options.headers,
        .extra_headers = options.extra_headers.items,
    };
    const request = client.request(options.method, url, request_options) catch |err| switch (err) {
        error.InvalidUri => l.argError(1, "invalid uri"),
        error.Unsupported => l.raiseErrorFmt("unsupported", .{}) catch unreachable,
        else => return err,
    };

    const fctx = try lallocator.create(FetchContext);
    fctx.* = .{
        .allocator = lallocator,
        .request = request,
        .server_header_buffer = server_header_buffer,
    };
    try context.scheduler.schedule(try Scheduler.Thread.init(.poll(FetchContext, fctx), l, l));

    return l.yield(1);
}

pub const Method = std.http.Method;

/// leaky structure, make sure to place in a arena
pub const FetchOptions = struct {
    method: Method = .GET,
    headers: std.http.Client.Request.Headers = .{},
    extra_headers: std.ArrayListUnmanaged(std.http.Header) = .{},
    body: []const u8 = &.{},
};

pub const HeaderMatch = enum {
    Host,
    Authorization,
    @"User-Agent",
    Connection,
    @"Accept-Encoding",
    @"Content-Type",

    pub fn set(
        self: HeaderMatch,
        allocator: std.mem.Allocator,
        headers: *std.http.Client.Request.Headers,
        value: []const u8,
    ) !void {
        const duped = try allocator.dupe(u8, value);
        switch (self) {
            .Host => headers.host = .{ .override = duped },
            .Authorization => headers.authorization = .{ .override = duped },
            .@"User-Agent" => headers.user_agent = .{ .override = duped },
            .Connection => headers.connection = .{ .override = duped },
            .@"Accept-Encoding" => headers.accept_encoding = .{ .override = duped },
            .@"Content-Type" => headers.content_type = .{ .override = duped },
        }
    }
};

pub fn parseFetchOptions(l: *luau.Luau, index: i32, allocator: std.mem.Allocator) !FetchOptions {
    if (l.typeOf(index) != .table) return .{};
    _ = l.getField(index, "method");
    const method = util.parseStringAsEnum(Method, l, -1, .GET) catch return error.InvalidMethod;
    l.pop(1);

    var headers: std.http.Client.Request.Headers = .{};
    var extra_headers: std.ArrayListUnmanaged(std.http.Header) = .{};
    switch (l.getField(index, "headers")) {
        .table => {
            l.pushNil();
            while (l.next(-2)) {
                const key = l.toString(-2) catch return error.InvalidHeaderKey;
                const value = l.toString(-1) catch return error.InvalidHeaderValue;
                if (std.meta.stringToEnum(HeaderMatch, key)) |got| {
                    try HeaderMatch.set(got, allocator, &headers, value);
                } else {
                    try extra_headers.append(allocator, .{
                        .name = try allocator.dupe(u8, key),
                        .value = try allocator.dupe(u8, value),
                    });
                }
                l.pop(1);
            }
            l.pop(1);
        },
        .nil => {},
        else => return .{},
    }

    if (l.getField(index, "body") == .nil) l.pushString("");
    const body = l.toString(-1) catch return error.InvalidBody;
    l.pop(1);

    return .{
        .method = method,
        .headers = headers,
        .extra_headers = extra_headers,
        .body = body,
    };
}

const std = @import("std");
const luau = @import("luau");

const util = @import("../util.zig");

const Context = @import("../Context.zig");
const Platform = @import("../Platform.zig");
const Scheduler = @import("../Scheduler.zig");

const io = @import("io.zig");
