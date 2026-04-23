// This is free and unencumbered software released into the public domain.

const config = @import("config");
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    var out = std.Io.File.stdout().writer(init.io, &.{});
    defer out.interface.flush() catch {};

    if (args.len != 2) {
        out.interface.print("usage: headcheck <url>\n", .{}) catch {};
        std.process.exit(2);
    }

    if (std.mem.eql(u8, args[1], "--help")) {
        out.interface.print("docs: https://pixelatedlabs.com/headcheck\n", .{}) catch {};
        std.process.exit(0);
    }

    if (std.mem.eql(u8, args[1], "--version")) {
        out.interface.print("version: {s}\n", .{config.version}) catch {};
        std.process.exit(0);
    }

    var client = std.http.Client{ .allocator = allocator, .io = init.io };
    defer client.deinit();

    const body = try allocator.alloc(u8, 1024);
    defer allocator.free(body);

    const url = std.Uri.parse(args[1]) catch {
        out.interface.print("unparseable: {s}\n", .{args[1]}) catch {};
        std.process.exit(2);
    };

    var request = try client.request(.GET, url, .{ .redirect_behavior = .unhandled });
    errdefer request.deinit();
    try request.sendBodiless();

    const response = try request.receiveHead(body);
    const status = @intFromEnum(response.head.status);
    request.deinit();

    if (status < 200 or status >= 300) {
        out.interface.print("failure: {d}\n", .{status}) catch {};
        std.process.exit(1);
    }

    out.interface.print("success: {d}\n", .{status}) catch {};
}
