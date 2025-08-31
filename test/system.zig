// This is free and unencumbered software released into the public domain.

const std = @import("std");

test "Too few arguments" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const binary = try std.process.getEnvVarOwned(allocator, "HEADCHECK_BINARY");

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const argv = [_][]const u8{binary};
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
    });
    try std.testing.expectEqualStrings("usage: headcheck <url>\n", child.stdout);
    try std.testing.expect(child.term.Exited == 2);
}
