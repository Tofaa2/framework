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
    const pool = @import("pool/build.zig").build(b, target, optimize);
    const math_lib = @import("math/build.zig").build(b, target, optimize);
    const rgfw = @import("rgfw/build.zig").build(b, target, optimize);
    const renderer = @import("renderer/build.zig").build(b, target, optimize, pool, math_lib.root_module, stb);

    const orin = @import("orin/build.zig").build(b, target, optimize, ecs);

    const base_imports: Imports = &.{
        .{ .name = "stb", .module = stb.root_module },
        .{ .name = "pool", .module = pool },
        .{ .name = "orin", .module = orin },
        .{ .name = "ecs", .module = ecs },
        .{ .name = "rgfw", .module = rgfw.root_module },
        .{ .name = "renderer", .module = renderer },
        .{ .name = "math", .module = math_lib.root_module },
    };

    setupExample(b, target, optimize, base_imports, &.{ rgfw, math_lib }, "sandbox", "examples/sandbox.zig");
    setupExample(b, target, optimize, base_imports, &.{ rgfw, math_lib }, "benchmark", "examples/benchmark.zig");
    setupExample(b, target, optimize, base_imports, &.{ rgfw, math_lib }, "assets_demo", "examples/assets.zig");
    setupExample(b, target, optimize, base_imports, &.{ rgfw, math_lib }, "postprocess_test", "examples/postprocess_test.zig");
    setupExample(b, target, optimize, base_imports, &.{ rgfw, math_lib }, "rendergraph_bloom_test", "examples/rendergraph_bloom_test.zig");
}

fn setupExample(b: *std.Build, target: Target, optimize: Optimize, imports: Imports, libs: []const *std.Build.Step.Compile, name: []const u8, path: []const u8) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .imports = imports,
            .root_source_file = b.path(path),
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
    if (b.graph.host.result.os.tag == .windows) {
        run_cmd.has_side_effects = true;
    }
    const run_step = b.step(name, b.fmt("Run {s}", .{name}));
    run_step.dependOn(&run_cmd.step);
}
