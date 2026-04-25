// This is free and unencumbered software released into the public domain.

const config = @import("config");
const std = @import("std");

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    var err = std.Io.File.stderr().writer(init.io, &.{});
    defer err.interface.flush() catch {};

    var out = std.Io.File.stdout().writer(init.io, &.{});
    defer out.interface.flush() catch {};

    if (args.len != 2) {
        err.interface.print("usage: headcheck <url>\n", .{}) catch {};
        return 2;
    }

    if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")) {
        out.interface.print("docs: https://pixelatedlabs.com/headcheck\n", .{}) catch {};
        return 0;
    }

    if (std.mem.eql(u8, args[1], "--version") or std.mem.eql(u8, args[1], "-v")) {
        out.interface.print("version: {s}\n", .{config.version}) catch {};
        return 0;
    }

    var client = std.http.Client{ .allocator = allocator, .io = init.io };
    defer client.deinit();

    const url = std.Uri.parse(args[1]) catch {
        err.interface.print("unparseable: {s}\n", .{args[1]}) catch {};
        return 2;
    };

    var request = client.request(.GET, url, .{ .redirect_behavior = .unhandled }) catch {
        err.interface.print("error: unknown host\n", .{}) catch {};
        return 1;
    };
    defer request.deinit();
    request.sendBodiless() catch {
        err.interface.print("error: connection refused\n", .{}) catch {};
        return 1;
    };

    const response = request.receiveHead(&.{}) catch {
        err.interface.print("error: connection refused\n", .{}) catch {};
        return 1;
    };
    const status = @intFromEnum(response.head.status);

    if (status < 200 or status >= 300) {
        err.interface.print("failure: {d}\n", .{status}) catch {};
        return 1;
    }

    out.interface.print("success: {d}\n", .{status}) catch {};
    return 0;
}
