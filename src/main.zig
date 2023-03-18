const std = @import("std");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const http = @import("http.zig");

const Context = http.Context;
const Status = http.Status;
const Server = http.Server;

pub const io_mode = .evented;

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = Server(handler).init(allocator, .{
        .address = "127.0.0.1",
        .port = 8080,
    });

    try server.listen();
}

fn handler(ctx: *Context) anyerror!void {
    if (std.mem.eql(u8, ctx.uri, "/sleep")) std.time.sleep(std.time.ns_per_s * 5);
    try ctx.respond(Status.OK, null, "some");
}
