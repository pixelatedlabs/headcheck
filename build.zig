// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Add version option.
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    // Compile source code in debug mode.
    const debug = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });
    debug.root_module.addOptions("config", options);
    b.installArtifact(debug);

    // Compile source code in release mode.
    const release = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .omit_frame_pointer = true,
            .optimize = .ReleaseSmall,
            .root_source_file = b.path("src/main.zig"),
            .single_threaded = true,
            .target = b.standardTargetOptions(.{
                .default_target = b.graph.host.query,
            }),
            .unwind_tables = .none,
        }),
    });
    release.root_module.addOptions("config", options);

    // Compress executable using UPX.
    const compress = b.addSystemCommand(&.{ "upx", "--lzma", "-9" });
    compress.stdio = .{ .check = .{} };
    compress.addFileArg(release.getEmittedBin());
    compress.step.dependOn(&release.step);

    // Run system tests.
    const testing = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    testing.addFileArg(release.getEmittedBin());
    testing.addArg(version);
    testing.step.dependOn(&compress.step);

    // Add executable to ZIP archive.
    const archive = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    const archive_path = archive.addOutputFileArg("headcheck.zip");
    archive.addFileArg(release.getEmittedBin());
    archive.step.dependOn(&testing.step);

    // Calculate platorm name, for example 'linux_arm64'.
    const platform = b.fmt(
        "{s}_{s}",
        .{
            @tagName(release.rootModuleTarget().os.tag),
            switch (release.rootModuleTarget().cpu.arch) {
                .aarch64 => "arm64",
                .x86_64 => "x64",
                else => |a| @tagName(a),
            },
        },
    );

    // Install raw output.
    const compile_output = b.addInstallArtifact(
        release,
        .{ .dest_dir = .{ .override = .{ .custom = platform } } },
    );
    compile_output.step.dependOn(&archive.step);

    // Install full compressed output.
    const full = b.addInstallFile(archive_path, b.fmt("{s}.zip", .{platform}));
    full.step.dependOn(&compile_output.step);

    // Install short compressed output.
    const short = b.addInstallFile(archive_path, b.fmt("{s}_{s}_{s}.zip", .{
        release.name,
        platform,
        version,
    }));
    short.step.dependOn(&full.step);

    // Setup package step.
    var package = b.step("package", "Package the executable");
    package.dependOn(&short.step);
}
