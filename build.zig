// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const options, const version = generateOptions(b);
    const compile_debug = compileDebug(b, options);
    const compile_release = compileRelease(b, options);
    const compress_upx = compressUpx(b, compile_release.getEmittedBin());
    const compress_zip, const zip_output = compressZip(b, compile_release.getEmittedBin());
    const test_system = testSystem(b, compile_release.getEmittedBin(), version);
    const artifact_debug = b.addInstallArtifact(compile_debug, .{});
    const artifact_full = artifactFull(b, compile_release, zip_output, version);
    const artifact_short = artifactShort(b, compile_release.rootModuleTarget(), zip_output);
    const artifact_release = artifactInstall(b, compile_release);
    const artifact_run = artifactRun(b, compile_debug);

    const option_install = b.getInstallStep();
    option_install.dependOn(&artifact_debug.step);

    const option_package = b.step("release", "Package for publishing");
    compress_upx.step.dependOn(&compile_release.step);
    test_system.step.dependOn(&compress_upx.step);
    compress_zip.step.dependOn(&test_system.step);
    artifact_release.step.dependOn(&compress_zip.step);
    artifact_full.step.dependOn(&artifact_release.step);
    artifact_short.step.dependOn(&artifact_full.step);
    option_package.dependOn(&artifact_short.step);

    const option_run = b.step("run", "Run the application");
    option_run.dependOn(&artifact_run.step);
}

fn artifactFull(b: *std.Build, compile: *std.Build.Step.Compile, file: std.Build.LazyPath, version: []const u8) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}_{s}_{s}.zip", .{
        compile.name,
        utilityPlatform(b, compile.rootModuleTarget()),
        version,
    }));
}

fn artifactInstall(b: *std.Build, compile: *std.Build.Step.Compile) *std.Build.Step.InstallArtifact {
    return b.addInstallArtifact(compile, .{
        .dest_dir = .{
            .override = .{
                .custom = utilityPlatform(b, compile.rootModuleTarget()),
            },
        },
    });
}

fn artifactShort(b: *std.Build, target: std.Target, file: std.Build.LazyPath) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}.zip", .{utilityPlatform(b, target)}));
}

fn artifactRun(b: *std.Build, compile: *std.Build.Step.Compile) *std.Build.Step.Run {
    const command = b.addRunArtifact(compile);
    if (b.args) |args| {
        command.addArgs(args);
    }
    return command;
}

fn compileDebug(b: *std.Build, options: *std.Build.Step.Options) *std.Build.Step.Compile {
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

fn compileRelease(b: *std.Build, options: *std.Build.Step.Options) *std.Build.Step.Compile {
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

fn compressUpx(b: *std.Build, bin: std.Build.LazyPath) *std.Build.Step.Run {
    const compress = b.addSystemCommand(&.{ "upx", "--lzma", "-9" });
    compress.stdio = .{ .check = .{} };
    compress.addFileArg(bin);
    return compress;
}

fn compressZip(b: *std.Build, bin: std.Build.LazyPath) struct { *std.Build.Step.Run, std.Build.LazyPath } {
    const command = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    const output = command.addOutputFileArg("headcheck.zip");
    command.addFileArg(bin);
    return .{ command, output };
}

fn generateOptions(b: *std.Build) struct { *std.Build.Step.Options, []const u8 } {
    const options = b.addOptions();
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";
    options.addOption([]const u8, "version", version);
    return .{ options, version };
}

fn testSystem(b: *std.Build, bin: std.Build.LazyPath, version: []const u8) *std.Build.Step.Run {
    const testing = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    testing.addFileArg(bin);
    testing.addArg(version);
    return testing;
}

fn utilityPlatform(b: *std.Build, target: std.Target) []u8 {
    return b.fmt(
        "{s}_{s}",
        .{
            @tagName(target.os.tag),
            switch (target.cpu.arch) {
                .aarch64 => "arm64",
                .x86_64 => "x64",
                else => |a| @tagName(a),
            },
        },
    );
}
