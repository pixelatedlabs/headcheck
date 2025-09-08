// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const options, const version = generateOptions(b);
    const debug = compileDebug(b, options);
    const command = run(b, debug);
    const release = compileRelease(b, options);
    const upx = compressUpx(b, release.getEmittedBin());
    const testing = testSystem(b, release.getEmittedBin(), version);
    const zip, const zip_output = compressZip(b, release.getEmittedBin());
    const compile_output = b.addInstallArtifact(
        release,
        .{ .dest_dir = .{ .override = .{ .custom = platform(b, release.rootModuleTarget()) } } },
    );
    const full = installShort(b, release.rootModuleTarget(), zip_output);
    const short = installLong(b, release, zip_output, version);

    b.installArtifact(debug);

    const package = b.step("release", "Package for publishing");
    upx.step.dependOn(&release.step);
    testing.step.dependOn(&upx.step);
    zip.step.dependOn(&testing.step);
    compile_output.step.dependOn(&zip.step);
    full.step.dependOn(&compile_output.step);
    short.step.dependOn(&full.step);
    package.dependOn(&short.step);

    const runCommand = b.step("run", "Run the application");
    runCommand.dependOn(&command.step);
}

fn run(b: *std.Build, compile: *std.Build.Step.Compile) *std.Build.Step.Run {
    const command = b.addRunArtifact(compile);
    if (b.args) |args| {
        command.addArgs(args);
    }
    return command;
}

fn generateOptions(b: *std.Build) struct { *std.Build.Step.Options, []const u8 } {
    const options = b.addOptions();
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";
    options.addOption([]const u8, "version", version);
    return .{ options, version };
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

fn testSystem(b: *std.Build, bin: std.Build.LazyPath, version: []const u8) *std.Build.Step.Run {
    const testing = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    testing.addFileArg(bin);
    testing.addArg(version);
    return testing;
}

fn compressZip(b: *std.Build, bin: std.Build.LazyPath) struct { *std.Build.Step.Run, std.Build.LazyPath } {
    const command = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    command.addFileArg(bin);
    const output = command.addOutputFileArg("headcheck.zip");
    return .{ command, output };
}

fn installShort(b: *std.Build, target: std.Target, file: std.Build.LazyPath) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}.zip", .{platform(b, target)}));
}

fn installLong(b: *std.Build, compile: *std.Build.Step.Compile, file: std.Build.LazyPath, version: []const u8) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}_{s}_{s}.zip", .{
        compile.name,
        platform(b, compile.rootModuleTarget()),
        version,
    }));
}

fn platform(b: *std.Build, target: std.Target) []u8 {
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
