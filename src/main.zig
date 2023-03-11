const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
pub const io_mode = .evented;

pub fn main() !void {
    var stream_server = StreamServer.init(.{});
    const address = try Address.parseIp4("127.0.0.1", 8080);
    try stream_server.listen(address);

    while(true) {
        const connection = try stream_server.accept();
        try handler(connection.stream);
    }
}

fn handler(stream: net.Stream) !void {
    defer stream.close();
    try stream.writer().print("Hello world from zig", .{});
}