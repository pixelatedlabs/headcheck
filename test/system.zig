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
