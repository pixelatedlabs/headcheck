// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Add version option.
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    // Compile source code.
    const compile = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .omit_frame_pointer = true,
            .optimize = .ReleaseSmall,
            .root_source_file = b.path("src/main.zig"),
            .single_threaded = true,
            .target = b.graph.host,
            .unwind_tables = .none,
        }),
    });
    compile.root_module.addOptions("config", options);

    // Compress executable using UPX.
    const compress = b.addSystemCommand(&.{ "upx", "--lzma", "-9" });
    compress.stdio = .{ .check = .{} };
    compress.addFileArg(compile.getEmittedBin());
    compress.step.dependOn(&compile.step);

    // Run python tests.
    const testing = b.addSystemCommand(&.{ "python", "test/system.py" });
    testing.addFileArg(compile.getEmittedBin());
    testing.addArg(version);
    testing.step.dependOn(&compress.step);

    // Add executable to ZIP archive.
    const archive = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    const archive_path = archive.addOutputFileArg("headcheck.zip");
    archive.addFileArg(compile.getEmittedBin());
    archive.step.dependOn(&testing.step);

    // Install raw output.
    const compile_output = b.addInstallArtifact(compile, .{});
    compile_output.step.dependOn(&archive.step);

    // Install full compressed output.
    const full = b.addInstallFile(archive_path, b.fmt("{s}_{s}.zip", .{
        @tagName(compile.rootModuleTarget().os.tag),
        switch (compile.rootModuleTarget().cpu.arch) {
            .x86_64 => "x64",
            else => |a| @tagName(a),
        },
    }));
    full.step.dependOn(&compile_output.step);

    // Install short compressed output.
    const short = b.addInstallFile(archive_path, b.fmt("{s}_{s}_{s}_{s}.zip", .{
        compile.name,
        @tagName(compile.rootModuleTarget().os.tag),
        switch (compile.rootModuleTarget().cpu.arch) {
            .x86_64 => "x64",
            else => |a| @tagName(a),
        },
        version,
    }));
    short.step.dependOn(&full.step);
    b.getInstallStep().dependOn(&short.step);
}
