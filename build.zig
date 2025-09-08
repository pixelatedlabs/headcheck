// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Configure build options.
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";

    // Add build options.
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    // Specify release modes.
    buildDebug(b, options);
    buildRun(b, options);
    buildRelease(b, options, version);
}

fn buildDebug(b: *std.Build, options: *std.Build.Step.Options) void {
    // Compile source code in debug mode.
    const debug = wip_compileDebug(b, options);
    b.installArtifact(debug);
}

fn buildRun(b: *std.Build, options: *std.Build.Step.Options) void {
    // Compile source code in standard mode.
    const compile = wip_compileDebug(b, options);
    b.installArtifact(compile);

    const command = b.addRunArtifact(compile);
    if (b.args) |args| {
        command.addArgs(args);
    }

    const run = b.step("run", "Run the application");
    run.dependOn(&command.step);
}

fn buildRelease(b: *std.Build, options: *std.Build.Step.Options, version: []const u8) void {
    const release = wip_compileRelease(b, options);
    const upx = wip_upx(b, release.getEmittedBin());
    const testing = wip_test(b, release.getEmittedBin(), version);
    const zip = wip_zip(b, release.getEmittedBin());

    upx.step.dependOn(&release.step);
    testing.step.dependOn(&upx.step);
    zip.step.dependOn(&testing.step);

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
    compile_output.step.dependOn(&zip.step);

    // Install full compressed output.
    const archive_path = zip.addOutputFileArg("headcheck.zip");
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
    var package = b.step("release", "Package for publishing");
    package.dependOn(&short.step);
}

fn wip_compileDebug(b: *std.Build, options: *std.Build.Step.Options) *std.Build.Step.Compile {
    const compile = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });
    compile.root_module.addOptions("config", options);
    return compile;
}

fn wip_compileRelease(b: *std.Build, options: *std.Build.Step.Options) *std.Build.Step.Compile {
    const compile = b.addExecutable(.{
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
    compile.root_module.addOptions("config", options);
    return compile;
}

fn wip_upx(b: *std.Build, bin: std.Build.LazyPath) *std.Build.Step.Run {
    const compress = b.addSystemCommand(&.{ "upx", "--lzma", "-9" });
    compress.stdio = .{ .check = .{} };
    compress.addFileArg(bin);
    return compress;
}

fn wip_test(b: *std.Build, bin: std.Build.LazyPath, version: []const u8) *std.Build.Step.Run {
    const testing = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    testing.addFileArg(bin);
    testing.addArg(version);
    return testing;
}

fn wip_zip(b: *std.Build, bin: std.Build.LazyPath) *std.Build.Step.Run {
    const archive = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    archive.addFileArg(bin);
    return archive;
}
