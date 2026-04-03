const std = @import("std");
const Build = std.Build;
const Module = std.Build.Module;
const Compile = std.Build.Step.Compile;
const Target = std.Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
const Imports = []const Module.Import;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const stb = @import("stb/build.zig").build(b, target, optimize);
    const ecs = @import("ecs/build.zig").build(b, target, optimize);
    const rgfw = @import("rgfw/build.zig").build(b, target, optimize);
    const renderer = @import("renderer/build.zig").build(b, target, optimize);
    const orin = @import("orin/build.zig").build(b, target, optimize, ecs);

    setupExamples(b, target, optimize, &.{
        .{ .name = "stb", .module = stb.root_module },
        .{ .name = "orin", .module = orin },
        .{ .name = "ecs", .module = ecs },
        .{ .name = "rgfw", .module = rgfw.root_module },
        .{ .name = "renderer", .module = renderer },
    }, &.{rgfw});
}

fn setupExamples(b: *std.Build, target: Target, optimize: Optimize, imports: Imports, libs: []const *std.Build.Step.Compile) void {
    const Example = struct {
        name: []const u8,
        path: []const u8,
    };

    const names: []const Example = &.{
        .{ .name = "sandbox", .path = "examples/sandbox.zig" },
        .{ .name = "benchmark", .path = "examples/benchmark.zig" },
        .{ .name = "assets_demo", .path = "examples/assets.zig" },
    };

    for (names) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .imports = imports,
                .root_source_file = b.path(example.path),
            }),
        });

        for (libs) |lib| {
            exe.linkLibrary(lib);
        }

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(example.name, "Run an example");
        run_step.dependOn(&run_cmd.step);
    }
}
