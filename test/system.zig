// This is free and unencumbered software released into the public domain.

const std = @import("std");

test "Too few arguments" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // const argv = [_][]const u8{args[1]};
    const argv = [_][]const u8{"/workspaces/Headcheck/zig-out/bin/headcheck"};
    // std.process.Child.run(.{})
    const child = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &argv,
    });
    // child.stderr_behavior = .Pipe;
    // child.stdout_behavior = .Pipe;
    // try child.spawn();
    // var stdout = std.ArrayListAlignedUnmanaged(u8, u29);
    // defer stdout.deinit();
    // var stderr = std.ArrayListAlignedUnmanaged(u8).init(std.testing.allocator);
    // defer stderr.deinit();
    // //yes, a bit overkill with max_output_bytes, but that's not the point here
    // try child.collectOutput(allocator, &stdout, &stderr, 50);
    // const exit = try child.wait();
    // const stdout = child.stdout orelse unreachable;
    // var buf: [4096]u8 = undefined;
    // const len = try stdout.preadAll(&buf, 0);
    // _ = len;
    // const eq = std.mem.eql(u8, &buf, "usage: headcheck <url>\n");
    // try std.testing.expect(eq);
    try std.testing.expect(child.term.Exited == 2);
}
