const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const Allocator = std.mem.Allocator;

pub const ParsingError = error {
    MethodNotValid,
    VersionNotValid,
};

pub const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTION,
    DELETE,
    pub fn fromString(s: []const u8) !Method {
        var method = std.meta.stringToEnum(Method, s);
        if (method) |m| {
            return m;
        } else {
            return ParsingError.MethodNotValid;
        }
    }
    pub fn asString(self: Method) []const u8 {
        return switch(self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .PATCH => "PATCH",
            .OPTION => "OPTION",
            .DELETE => "DELETE",
        };
    }
};

pub const Version = enum {
    @"HTTP/1.1",
    @"HTTP/2",
    pub fn fromString(s: []const u8) !Version {
        var version = std.meta.stringToEnum(Version, s);
        if (version) |v| {
            return v;
        } else {
            return ParsingError.VersionNotValid;
        }
    }
    pub fn asString(self: Version) []const u8 {
        if (self == Version.@"HTTP/1.1") return "HTTP/1.1";
        if (self == Version.@"HTTP/2") return "HTTP/2";
        unreachable;
    }
};

pub const Status = enum {
    OK,
    pub fn asString(self: Status) []const u8 {
        if (self == Status.OK) return "OK";
    }
    pub fn asNumber(self: Status) u8 {
        if (self == Status.OK) return 200;
    }
};

pub const Context = struct {
    method: Method,
    uri: []const u8,
    version: Version,
    headers: std.StringHashMap([]const u8),
    stream: net.Stream,

    pub fn bodyReader(self: *Context) net.Stream.Reader {
        return self.stream.reader();
    }

    pub fn response(self: *Context) net.Stream.Writer {
        return self.stream.writer();
    }

    pub fn respond(self: *Context, status: Status, maybe_headers: ?std.StringHashMap([]const u8), body: []const u8) !void {
        var writer = self.response();
        try writer.print("{s} {} {s}\r\n", .{self.version.asString(), status.asNumber(), status.asString()});
        if (maybe_headers) |headers| {
            var headers_iter = headers.iterator();
            while(headers_iter.next()) |entry| {
                try writer.print("{s}: {s}\n", .{entry.key_ptr.*, entry.value_ptr.*});
            }
        }

        try writer.print("\r\n", .{});

        _ = try writer.write(body);
    }

    pub fn debugPrintRequest(self: *Context) void {
        std.debug.print("method: {s}\nuri: {s}\nversion: {s}\n", .{self.method.asString(), self.uri, self.version.asString()});
        
        var headers_iter = self.headers.iterator();
        while(headers_iter.next()) |entry| {
            std.debug.print("{s}: {s}\n", .{entry.key_ptr.*, entry.value_ptr.*});
        }
    }

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !Context {
        var first_line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        first_line = first_line[0..first_line.len - 1];
        var first_line_iter = std.mem.split(u8, first_line, " ");

        const method = first_line_iter.next().?;
        const uri = first_line_iter.next().?;
        const version = first_line_iter.next().?;
        var headers = std.StringHashMap([]const u8).init(allocator);

        while(true) {
            var line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
            if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;
            line = line[0..line.len];

            var line_iter = std.mem.split(u8, line, ":");
            const key = line_iter.next().?;
            var value = line_iter.next().?;
            if (value[0] == ' ') value = value[1..];
            try headers.put(key, value);
        }

        return Context {
            .headers = headers,
            .method = try Method.fromString(method),
            .version = try Version.fromString(version),
            .uri = uri,
            .stream = stream,
        };
    }
};

pub const Server = struct {
    config: Config,
    allocator: Allocator,
    address: net.Address,
    stream_server: net.StreamServer = undefined,
    frames: std.ArrayList(*Connection),

    const Connection = struct {
        frame: @Frame(handler),
    };


    pub const Config = struct {
        address: []const u8 = "127.0.0.1",
        port: u16 = 8080,
    };

    pub fn init(allocator: Allocator, config: Config) !Server {
        return Server{
            .allocator = allocator,
            .config = config,
            .address = try Address.parseIp4(config.address, config.port),
            .frames = std.ArrayList(*Connection).init(allocator),
        };
    }

    pub fn deinit(self: *Server) void {
        self.stream_server.close();
        self.stream_server.deinit();
    }

    fn handler(allocator: std.mem.Allocator, stream: net.Stream) !void {
        defer stream.close();

        var context = try Context.init(allocator,stream);
        context.debugPrintRequest();

        try context.respond(Status.OK, null, "Hello From ZIG");
    }

    pub fn listen(self: *Server) !void {
        self.stream_server = StreamServer.init(.{});
        try self.stream_server.listen(self.address);

        std.debug.print("Listening on {}\n", .{self.address});

        while(true) {
            const connection = try self.stream_server.accept();

            // async call
            var conn = try self.allocator.create(Connection);
            conn.* = .{
                .frame = async handler(self.allocator, connection.stream), 
            };
            try self.frames.append(conn);
        }
    }
};