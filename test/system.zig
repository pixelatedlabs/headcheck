// This is free and unencumbered software released into the public domain.

const std = @import("std");

const Args = struct { binary: []u8, version: []u8 };

const address = std.net.Address.initIp4([_]u8{ 127, 0, 0, 1 }, 47638);
var running = true;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var thread = try std.Thread.spawn(.{}, server, .{});
    defer thread.join();

    const testArgs = Args{
        .binary = args[1],
        .version = args[2],
    };

    try invalidUrl(allocator, testArgs);
    try helpText(allocator, testArgs);
    try tooFewArguments(allocator, testArgs);
    try tooManyArguments(allocator, testArgs);
    try validUrlWithSuccessfulResponse(allocator, testArgs);
    try validUrlWithUnsuccessfulResponse(allocator, testArgs);
    try versionText(allocator, testArgs);

    running = false;
    const connection = std.net.tcpConnectToAddress(address) catch return;
    connection.close();
}

fn server() !void {
    var serverTcp = try address.listen(.{ .reuse_address = true });
    defer serverTcp.deinit();

    while (running) {
        var connection = try serverTcp.accept();
        defer connection.stream.close();

        var buffer: [1024]u8 = undefined;
        var serverHttp = std.http.Server.init(connection, &buffer);

        var request = serverHttp.receiveHead() catch return;
        const trimmed = std.mem.trimLeft(u8, request.head.target, "/");
        const value = try std.fmt.parseInt(i32, trimmed, 10);
        try request.respond("", .{ .status = @enumFromInt(value) });
    }
}

fn invalidUrl(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "baz" },
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("unparseable: baz\n", child.stdout);
}

fn helpText(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "--help" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("docs: https://pixelatedlabs.com/headcheck\n", child.stdout);
}

fn tooFewArguments(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{args.binary},
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stdout);
}

fn tooManyArguments(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "foo", "bar" },
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stdout);
}

fn validUrlWithSuccessfulResponse(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "http://localhost:47638/200" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("success: 200\n", child.stdout);
}

fn validUrlWithUnsuccessfulResponse(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "http://localhost:47638/301" },
    });

    try std.testing.expectEqual(1, child.term.Exited);
    try std.testing.expectEqualStrings("failure: 301\n", child.stdout);
}

fn versionText(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "--version" },
    });

    const output = try std.fmt.allocPrint(allocator, "version: {s}\n", .{args.version});
    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings(output, child.stdout);
}
