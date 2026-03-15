const std = @import("std");
const Build = std.Build;
const Module = std.Build.Module;
const Target = std.Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;

const zbgfx = @import("zbgfx");

const Imports = []const Module.Import;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const math = @import("libs/math/build.zig").apply(b, target, optimize);
    const type_id = @import("libs/type_id/build.zig").apply(b, target, optimize);
    const window = @import("libs/window/build.zig").apply(b, target, optimize);
    const stb = @import("libs/stb/build.zig").apply(b, target, optimize);
    const dyn = @import("libs/dyn/build.zig").apply(b, target, optimize);
    const plugin = @import("libs/plugin/build.zig").apply(b, target, optimize);
    const scheduler = @import("libs/scheduler/build.zig").apply(b, target, optimize);

    const runtime = buildRuntime(b, target, optimize, &.{
        .{ .name = "math", .module = math },
        .{ .name = "stb", .module = stb },
        .{ .name = "window", .module = window },
        .{ .name = "dyn", .module = dyn },
        .{ .name = "type_id", .module = type_id },
        .{ .name = "plugin", .module = plugin },
        .{ .name = "scheduler", .module = scheduler },
    });
    try linkBgfx(b, target, optimize, runtime);
    linkSimpleModDep(b, runtime, "entt", "ecs", "zig-ecs");
    buildSandbox(b, target, optimize, &.{
        .{ .name = "framework-runtime", .module = runtime },
    });
}
fn exportLib(b: *std.Build, target: Target, optimize: Optimize, impl: anytype) *Module {
    return impl.apply(b, target, optimize);
}

fn buildRuntime(b: *Build, target: Target, optimize: Optimize, imports: Imports) *Module {
    const runtime = b.addModule("runtime", .{
        .root_source_file = b.path("runtime/root.zig"),
        .optimize = optimize,
        .target = target,
        .imports = imports,
    });

    return runtime;
}

fn linkBgfx(b: *Build, target: Target, optimize: Optimize, runtime: *Module) !void {
    _ = optimize;
    const zbgfx_dep = b.dependency("zbgfx", .{});
    runtime.addImport("bgfx", zbgfx_dep.module("zbgfx"));
    runtime.linkLibrary(zbgfx_dep.artifact("bgfx"));
    const install_shaderc_step = try zbgfx.build_step.installShaderc(b, zbgfx_dep);
    const shaders_includes = &.{zbgfx_dep.path("shaders")};
    const shaders_module = try zbgfx.build_step.compileShaders(
        b,
        target,
        install_shaderc_step,
        zbgfx_dep,
        shaders_includes,
        &.{
            .{
                .name = "fs_basic",
                .shaderType = .fragment,
                .path = b.path("runtime/renderer/shaders/fs_basic.sc"),
            },
            .{
                .name = "vs_basic",
                .shaderType = .vertex,
                .path = b.path("runtime/renderer/shaders/vs_basic.sc"),
            },
        },
    );
    runtime.addImport("shader_module", shaders_module);
}

fn buildSandbox(b: *Build, target: Target, optimize: Optimize, imports: Imports) void {
    const exe = b.addExecutable(.{
        .name = "sandbox",
        .root_module = b.createModule(.{
            .optimize = optimize,
            .target = target,
            .root_source_file = b.path("sandbox/main.zig"),
            .imports = imports,
        }),
    });
    b.installArtifact(exe);
    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn linkSimpleModDep(b: *std.Build, module: *std.Build.Module, dep_name: []const u8, name: []const u8, mod_name: []const u8) void {
    const dep = b.dependency(dep_name, .{});
    const mod = dep.module(mod_name);
    module.addImport(name, mod);
}
fn linkSimpleModDepWithArtifact(b: *std.Build, module: *std.Build.Module, dep_name: []const u8, name: []const u8, mod_name: []const u8, artifact: []const u8) void {
    const dep = b.dependency(dep_name, .{});
    const mod = dep.module(mod_name);
    module.addImport(name, mod);
    module.linkLibrary(dep.artifact(artifact));
}
