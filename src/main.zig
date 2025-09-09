// This is free and unencumbered software released into the public domain.

const config = @import("config");
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

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

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = std.Uri.parse(args[1]) catch {
        print("unparseable: {s}\n", .{args[1]});
        std.process.exit(2);
    };

    var req = try client.request(.HEAD, url, .{});
    defer req.deinit();
    try req.sendBodiless();

    const response = try req.receiveHead(&.{});
    const status = @intFromEnum(response.head.status);

    if (status < 200 or status >= 300) {
        print("failure: {d}\n", .{status});
        std.process.exit(1);
    }

    print("success: {d}\n", .{status});
}

var out = std.fs.File.Writer.initStreaming(std.fs.File.stdout(), &.{});
fn print(comptime fmt: []const u8, args: anytype) void {
    out.interface.print(fmt, args) catch return;
}
