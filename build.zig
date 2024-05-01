const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigist-v0.12",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addAnonymousImport("datetime", .{ .root_source_file = .{ .path = b.pathFromRoot("lib/datetime.zig") } });
    exe.root_module.addAnonymousImport("env", .{ .root_source_file = .{ .path = b.pathFromRoot("lib/env.zig") } });
    exe.root_module.addAnonymousImport("http", .{ .root_source_file = .{ .path = b.pathFromRoot("lib/http.zig") } });
    exe.root_module.addAnonymousImport("payload", .{ .root_source_file = .{ .path = b.pathFromRoot("lib/payload.zig") } });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    var test_step = b.step("test", "Run unit tests");
    const test_paths = [_][]const u8{ "lib/payload.zig", "lib/datetime.zig", "lib/env.zig", "src/main.zig" };
    const test_names = [_][]const u8{ "test payload", "test datetime", "test env", "test main" };

    for (test_paths, 0..) |path, i| {
        const unit_tests = b.addTest(.{
            .name = test_names[i],
            .root_source_file = .{ .path = path },
            .target = target,
            .optimize = optimize,
        });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
