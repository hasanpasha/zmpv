const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zmpv_lib",
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkSystemLibrary("mpv");

    b.installArtifact(lib);

    const module = b.addModule("zmpv", .{
        .root_source_file = .{ .path = "src/root.zig" },
    });
    _ = module;

    const Example = struct {
        name: []const u8,
        src: []const u8,
    };

    const examples = [_]Example{
        .{ .name = "sdl-opengl", .src = "src/sdl_opengl_example.zig" },
        .{ .name = "sdl-sw", .src = "src/sdl_sw_example.zig" },
        .{ .name = "stream-cb", .src = "src/stream_cb_example.zig" },
    };

    for (examples) |example| {
        const e_exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = .{ .path = example.src },
            .target = target,
            .optimize = optimize,
        });

        e_exe.linkLibC();
        e_exe.linkSystemLibrary("SDL2");
        e_exe.linkSystemLibrary("mpv");
        b.installArtifact(e_exe);
        const e_run_cmd = b.addRunArtifact(e_exe);
        e_run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            e_run_cmd.addArgs(args);
        }
        const e_run_step = b.step(example.name, "Run the example");
        e_run_step.dependOn(&e_run_cmd.step);
    }

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("mpv");

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
