const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zmpv_module = b.addModule("zmpv", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const Example = enum {
        simple,
        streamcb,
        sdl_opengl,
        sdl_sw,
    };
    const example_option = b.option(Example, "example", "Example to run (default: simple)") orelse .simple;
    const example_step = b.step("example", "Run example");
    const example = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path(
            b.fmt("examples/{s}.zig", .{@tagName(example_option)}),
        ),
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    example.root_module.addOptions("config", options);
    const filepath_option = b.option([]const u8, "filepath", "Filepath to play (default: 'resources/sample.mp4')") orelse "resources/sample.mp4";
    options.addOption([]const u8, "filepath", filepath_option);

    example.root_module.addImport("zmpv", zmpv_module);
    example.linkLibC();
    example.linkSystemLibrary("mpv");
    if (example_option == .sdl_opengl or example_option == .sdl_sw) example.linkSystemLibrary("sdl2");


    const example_run = b.addRunArtifact(example);
    example_step.dependOn(&example_run.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("mpv");

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
