// This is free and unencumbered software released into the public domain.

const std = @import("std");

const Args = struct { binary: []const u8, version: []const u8 };

const address = std.Io.net.IpAddress{ .ip4 = .{ .bytes = [_]u8{ 127, 0, 0, 1 }, .port = 47638 } };
var running = true;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    var thread = try std.Thread.spawn(.{}, run, .{init.io});
    defer thread.join();

    const testArgs = Args{
        .binary = args[1],
        .version = args[2],
    };

    try testInvalidHost(allocator, init.io, testArgs);
    try testInvalidUrl(allocator, init.io, testArgs);
    try testHelpLongText(allocator, init.io, testArgs);
    try testHelpShortText(allocator, init.io, testArgs);
    try testTooFewArguments(allocator, init.io, testArgs);
    try testTooManyArguments(allocator, init.io, testArgs);
    try testValidUrlWithSuccessfulResponse(allocator, init.io, testArgs);
    try testValidUrlWithUnsuccessfulResponse(allocator, init.io, testArgs);
    try testVersionLongText(allocator, init.io, testArgs);
    try testVersionShortText(allocator, init.io, testArgs);

    running = false;
    const connection = address.connect(init.io, .{ .mode = .stream }) catch return;
    connection.close(init.io);
}

fn run(io: std.Io) !void {
    var listener = try address.listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);

    while (running) {
        var connection = try listener.accept(io);
        defer connection.close(io);

        var read_buffer: [1024]u8 = undefined;
        var read_http = connection.reader(io, &read_buffer);

        var write_buffer: [1024]u8 = undefined;
        var write_http = connection.writer(io, &write_buffer);

        var server = std.http.Server.init(&read_http.interface, &write_http.interface);
        var request = server.receiveHead() catch return;

        const trimmed = std.mem.trimStart(u8, request.head.target, "/");
        const value = try std.fmt.parseInt(i32, trimmed, 10);

        try request.respond("", .{ .status = @enumFromInt(value) });
    }
}

fn testInvalidHost(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "http://unknown.local" },
    });

    try std.testing.expectEqual(1, child.term.exited);
    try std.testing.expectEqualStrings("error: unknown host\n", child.stderr);
    try std.testing.expectEqualStrings("", child.stdout);
}

fn testInvalidUrl(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "baz" },
    });

    try std.testing.expectEqual(2, child.term.exited);
    try std.testing.expectEqualStrings("unparseable: baz\n", child.stderr);
    try std.testing.expectEqualStrings("", child.stdout);
}

fn testHelpLongText(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "--help" },
    });

    try std.testing.expectEqual(0, child.term.exited);
    try std.testing.expectEqualStrings("", child.stderr);
    try std.testing.expectEqualStrings("docs: https://pixelatedlabs.com/headcheck\n", child.stdout);
}

fn testHelpShortText(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "-h" },
    });

    try std.testing.expectEqual(0, child.term.exited);
    try std.testing.expectEqualStrings("", child.stderr);
    try std.testing.expectEqualStrings("docs: https://pixelatedlabs.com/headcheck\n", child.stdout);
}

fn testTooFewArguments(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{args.binary},
    });

    try std.testing.expectEqual(2, child.term.exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stderr);
    try std.testing.expectEqualStrings("", child.stdout);
}

fn testTooManyArguments(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "foo", "bar" },
    });

    try std.testing.expectEqual(2, child.term.exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stderr);
    try std.testing.expectEqualStrings("", child.stdout);
}

fn testValidUrlWithSuccessfulResponse(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "http://localhost:47638/200" },
    });

    try std.testing.expectEqual(0, child.term.exited);
    try std.testing.expectEqualStrings("", child.stderr);
    try std.testing.expectEqualStrings("success: 200\n", child.stdout);
}

fn testValidUrlWithUnsuccessfulResponse(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "http://localhost:47638/301" },
    });

    try std.testing.expectEqual(1, child.term.exited);
    try std.testing.expectEqualStrings("failure: 301\n", child.stderr);
    try std.testing.expectEqualStrings("", child.stdout);
}

fn testVersionLongText(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "--version" },
    });

    const output = try std.fmt.allocPrint(allocator, "version: {s}\n", .{args.version});
    try std.testing.expectEqual(0, child.term.exited);
    try std.testing.expectEqualStrings("", child.stderr);
    try std.testing.expectEqualStrings(output, child.stdout);
}

fn testVersionShortText(allocator: std.mem.Allocator, io: std.Io, args: Args) !void {
    const child = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ args.binary, "-v" },
    });

    const output = try std.fmt.allocPrint(allocator, "version: {s}\n", .{args.version});
    try std.testing.expectEqual(0, child.term.exited);
    try std.testing.expectEqualStrings("", child.stderr);
    try std.testing.expectEqualStrings(output, child.stdout);
}
