// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Configure build options.
    const version = b.option([]const u8, "version", "version") orelse "0.0.0";

    // Add build options.
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    const compile = wip_compileDebug(b, options);
    b.installArtifact(compile);

    const command = b.addRunArtifact(compile);
    if (b.args) |args| {
        command.addArgs(args);
    }

    const run = b.step("run", "Run the application");
    run.dependOn(&command.step);

    const debug = wip_compileDebug(b, options);
    b.installArtifact(debug);

    const release = wip_compileRelease(b, options);
    const upx = wip_upx(b, release.getEmittedBin());
    const testing = wip_test(b, release.getEmittedBin(), version);
    const zip, const zip_output = wip_zip(b, release.getEmittedBin());
    const compile_output = b.addInstallArtifact(
        release,
        .{ .dest_dir = .{ .override = .{ .custom = wip_platform(b, release.rootModuleTarget()) } } },
    );
    const full = wip_installShort(b, release.rootModuleTarget(), zip_output);
    const short = wip_installLong(b, release, zip_output, version);
    var package = b.step("release", "Package for publishing");

    upx.step.dependOn(&release.step);
    testing.step.dependOn(&upx.step);
    zip.step.dependOn(&testing.step);
    compile_output.step.dependOn(&zip.step);
    full.step.dependOn(&compile_output.step);
    short.step.dependOn(&full.step);
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

fn wip_zip(b: *std.Build, bin: std.Build.LazyPath) struct { *std.Build.Step.Run, std.Build.LazyPath } {
    const command = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    command.addFileArg(bin);
    const output = command.addOutputFileArg("headcheck.zip");
    return .{ command, output };
}

fn wip_installShort(b: *std.Build, target: std.Target, file: std.Build.LazyPath) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}.zip", .{wip_platform(b, target)}));
}

fn wip_installLong(b: *std.Build, compile: *std.Build.Step.Compile, file: std.Build.LazyPath, version: []const u8) *std.Build.Step.InstallFile {
    return b.addInstallFile(file, b.fmt("{s}_{s}_{s}.zip", .{
        compile.name,
        wip_platform(b, compile.rootModuleTarget()),
        version,
    }));
}

fn wip_platform(b: *std.Build, target: std.Target) []u8 {
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
