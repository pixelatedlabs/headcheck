// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const options, const version = generateOptions(b);
    const compile_debug = compileDebug(b, options);
    const compile_release = compileRelease(b, options);
    const compress_zip, const zip_output = compressZip(b, compile_release.getEmittedBin());
    const name_full = nameFull(b, compile_release, version);
    const name_platform = namePlatform(b, compile_release.rootModuleTarget());
    const name_short = nameShort(b, compile_release);

    buildOption(&.{
        &b.addInstallArtifact(compile_debug, .{}).step,
        b.getInstallStep(),
    });

    buildOption(&.{
        &compile_release.step,
        &compressUpx(b, compile_release.getEmittedBin()).step,
        &testSystem(b, compile_release.getEmittedBin(), version).step,
        &compress_zip.step,
        &artifactInstall(b, compile_release, name_platform).step,
        &artifactFull(b, zip_output, name_full).step,
        &artifactShort(b, zip_output, name_short).step,
        b.step("release", "Package for publishing"),
    });

    buildOption(&.{
        &artifactRun(b, compile_debug).step,
        b.step("run", "Run the application"),
    });
}

fn buildOption(steps: []const *std.Build.Step) void {
    var last = steps[0];
    for (steps[1..]) |step| {
        step.dependOn(last);
        last = step;
    }
}

fn artifactFull(b: *std.Build, file: std.Build.LazyPath, name: []const u8) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, name);
}

fn artifactInstall(b: *std.Build, compile: *std.Build.Step.Compile, name: []const u8) *std.Build.Step.InstallArtifact {
    return b.addInstallArtifact(compile, .{
        .dest_dir = .{
            .override = .{
                .custom = name,
            },
        },
    });
}

fn artifactShort(b: *std.Build, file: std.Build.LazyPath, name: []const u8) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, name);
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

fn nameFull(b: *std.Build, compile: *std.Build.Step.Compile, version: []const u8) []const u8 {
    return b.fmt("{s}_{s}_{s}.zip", .{
        compile.name,
        namePlatform(b, compile.rootModuleTarget()),
        version,
    });
}

fn namePlatform(b: *std.Build, target: std.Target) []u8 {
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

fn nameShort(b: *std.Build, compile: *std.Build.Step.Compile) []const u8 {
    return b.fmt("{s}.zip", .{namePlatform(b, compile.rootModuleTarget())});
}

fn testSystem(b: *std.Build, bin: std.Build.LazyPath, version: []const u8) *std.Build.Step.Run {
    const testing = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    testing.addFileArg(bin);
    testing.addArg(version);
    return testing;
}
