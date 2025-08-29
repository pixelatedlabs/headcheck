// This is free and unencumbered software released into the public domain.

const config = @import("config");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    if (args.len != 2) {
        print("usage: headcheck <url>\n", .{});
        std.process.exit(2);
    }

    if (std.mem.eql(u8, args[1], "--help")) {
        print("docs: https://pixelatedlabs.com/headcheck\n", .{});
        std.process.exit(0);
    }

    if (std.mem.eql(u8, args[1], "--version")) {
        print("version: {s}\n", .{config.version});
        std.process.exit(0);
    }

    var client = std.http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    const url = std.Uri.parse(args[1]) catch {
        print("unparseable: {s}\n", .{args[1]});
        std.process.exit(2);
    };

    var buf: [4096]u8 = undefined;
    var req = try client.open(.HEAD, url, .{ .server_header_buffer = &buf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const status = @intFromEnum(req.response.status);
    if (status < 200 or status >= 300) {
        print("failure: {d}\n", .{status});
        std.process.exit(1);
    }

    print("success: {d}\n", .{status});
}

fn print(comptime fmt: []const u8, args: anytype) void {
    const writer = std.io.getStdOut().writer();
    nosuspend writer.print(fmt, args) catch return;
}
