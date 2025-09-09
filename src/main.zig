// This is free and unencumbered software released into the public domain.

const config = @import("config");
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var out = std.fs.File.stdout().writer(&.{});
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

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const url = std.Uri.parse(args[1]) catch {
        out.interface.print("unparseable: {s}\n", .{args[1]}) catch {};
        std.process.exit(2);
    };

    var req = try client.request(.HEAD, url, .{});
    defer req.deinit();
    try req.sendBodiless();

    const response = try req.receiveHead(&.{});
    const status = @intFromEnum(response.head.status);

    if (status < 200 or status >= 300) {
        out.interface.print("failure: {d}\n", .{status}) catch {};
        std.process.exit(1);
    }

    out.interface.print("success: {d}\n", .{status}) catch {};
}
