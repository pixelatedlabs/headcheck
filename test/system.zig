// This is free and unencumbered software released into the public domain.

const std = @import("std");

test "Too few arguments" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{binary},
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stdout);
}

test "Too many arguments" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "foo", "bar" },
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stdout);
}

test "Invalid URL" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "baz" },
    });

    try std.testing.expectEqual(2, child.term.Exited);
    try std.testing.expectEqualStrings("unparseable: baz\n", child.stdout);
}

test "Valid URL with successful response" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "http://www.google.com" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("success: 200\n", child.stdout);
}

test "Valid URL with unsuccessful response" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "http://google.com" },
    });

    try std.testing.expectEqual(1, child.term.Exited);
    try std.testing.expectEqualStrings("failure: 301\n", child.stdout);
}

test "Help text" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "--help" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("docs: https://pixelatedlabs.com/headcheck\n", child.stdout);
}

test "Version text" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ binary, "--version" },
    });

    try std.testing.expectEqual(0, child.term.Exited);
    try std.testing.expectEqualStrings("version: 0.0.0\n", child.stdout);
}
