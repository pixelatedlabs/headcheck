// This is free and unencumbered software released into the public domain.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = b.graph.host.query });

    const version = b.option([]const u8, "version", "version") orelse "0.0.0";

    const options = b.addOptions();
    options.addOption([]const u8, "version", version);

    const compile_debug_step = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .optimize = .Debug,
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });
    compile_debug_step.root_module.addOptions("config", options);

    const compile_release_step = b.addExecutable(.{
        .name = "headcheck",
        .root_module = b.createModule(.{
            .omit_frame_pointer = true,
            .optimize = .ReleaseSmall,
            .root_source_file = b.path("src/main.zig"),
            .single_threaded = true,
            .target = target,
            .unwind_tables = .none,
        }),
    });
    compile_release_step.root_module.addOptions("config", options);
    const compile_release_output = compile_release_step.getEmittedBin();

    const upx_step = b.addSystemCommand(&.{ "upx", "--lzma", "-9" });
    upx_step.stdio = .{ .check = .{} };
    upx_step.addFileArg(compile_release_output);
    upx_step.step.dependOn(&compile_release_step.step);

    const test_step = b.addSystemCommand(&.{ "zig", "run", "test/system.zig", "--" });
    test_step.addFileArg(compile_release_output);
    test_step.addArg(version);
    test_step.step.dependOn(&upx_step.step);

    const zip_step = b.addSystemCommand(&.{ "zip", "--junk-paths" });
    const zip_output = zip_step.addOutputFileArg("headcheck.zip");
    zip_step.addFileArg(compile_release_output);
    zip_step.step.dependOn(&test_step.step);

    const platform = b.fmt(
        "{s}_{s}",
        .{
            @tagName(target.result.os.tag),
            switch (target.result.cpu.arch) {
                .aarch64 => "arm64",
                .x86_64 => "x64",
                else => |a| @tagName(a),
            },
        },
    );

    const artifact_exe_debug_step = b.addInstallArtifact(compile_debug_step, .{});

    const artifact_exe_release_step = b.addInstallArtifact(compile_release_step, .{
        .dest_dir = .{
            .override = .{
                .custom = platform,
            },
        },
    });
    artifact_exe_release_step.step.dependOn(&zip_step.step);

    const artifact_zip_full_step = b.addInstallFile(zip_output, b.fmt("{s}_{s}_{s}.zip", .{
        compile_release_step.name,
        platform,
        version,
    }));
    artifact_zip_full_step.step.dependOn(&artifact_exe_release_step.step);

    const artifact_zip_short_step = b.addInstallFile(zip_output, b.fmt("{s}.zip", .{platform}));
    artifact_zip_short_step.step.dependOn(&artifact_exe_release_step.step);

    const run_step = b.addRunArtifact(compile_debug_step);
    if (b.args) |args| {
        run_step.addArgs(args);
    }
    run_step.step.dependOn(&compile_debug_step.step);

    const option_install = b.getInstallStep();
    option_install.dependOn(&artifact_exe_debug_step.step);

    const option_package = b.step("release", "Package for publishing");
    option_package.dependOn(&artifact_zip_full_step.step);
    option_package.dependOn(&artifact_zip_short_step.step);

    const option_run = b.step("run", "Run the application");
    option_run.dependOn(&run_step.step);
}
