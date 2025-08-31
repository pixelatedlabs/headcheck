// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const argv = [_][]const u8{args[1]};
    var child = std.process.Child.init(&argv, allocator);
    try child.spawn();
    const exit = try child.wait();
    try std.testing.expect(exit.Exited == 2);
}
