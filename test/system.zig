// This is free and unencumbered software released into the public domain.

const std = @import("std");

const Args = struct { binary: []u8, version: []u8 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = Args{
        .binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY"),
        .version = try std.process.getEnvVarOwned(allocator, "HEADCHECK_VERSION"),
    };

    try tooFewArguments(allocator, args);
    try tooManyArguments(allocator, args);
    try invalidUrl(allocator, args);
    try validUrlWithSuccessfulResponse(allocator, args);
    try validUrlWithUnsuccessfulResponse(allocator, args);
    try helpText(allocator, args);
    try versionText(allocator, args);
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

fn invalidUrl(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "baz" },
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("unparseable: baz\n", child.stdout);
}

fn validUrlWithSuccessfulResponse(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "http://www.google.com" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("success: 200\n", child.stdout);
}

fn validUrlWithUnsuccessfulResponse(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "http://google.com" },
    });

    try std.testing.expectEqual(1, child.term.Exited);
    try std.testing.expectEqualStrings("failure: 301\n", child.stdout);
}

fn helpText(allocator: std.mem.Allocator, args: Args) !void {
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ args.binary, "--help" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("docs: https://pixelatedlabs.com/headcheck\n", child.stdout);
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
