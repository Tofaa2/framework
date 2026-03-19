const std = @import("std");
const Build = std.Build;
const Module = std.Build.Module;
const Target = std.Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
const Imports = []const Module.Import;

const zbgfx = @import("zbgfx");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const thirdparty = b.addLibrary(.{ .name = "framework-thirdparty", .root_module = b.createModule(.{
        .link_libc = true,
        .root_source_file = b.path("thirdparty/root.zig"),
        .optimize = optimize,
        .target = target,
    }) });
    thirdparty.addIncludePath(b.path("thirdparty/"));
    thirdparty.addCSourceFiles(.{
        .files = &.{ "RGFW_Impl.c", "stb_truetype_impl.c" },
        .root = b.path("thirdparty/"),
    });
    switch (target.result.os.tag) {
        .windows => {
            thirdparty.root_module.linkSystemLibrary("gdi32", .{ .needed = true });
        },
        else => {},
    }
    const runtime = b.addModule("runtime", .{
        .link_libc = true,
        .link_libcpp = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/root.zig"),
    });
    runtime.addImport("thirdparty", thirdparty.root_module);
    runtime.linkLibrary(thirdparty);
    linkSimpleModDep(b, runtime, "entt", "ecs", "zig-ecs");
    try linkBgfx(b, target, optimize, runtime);
    const sandbox = buildSandbox(b, target, optimize, &.{.{ .name = "runtime", .module = runtime }});

    const mod_tests = b.addTest(.{
        .root_module = runtime,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const exe_tests = b.addTest(.{
        .root_module = sandbox.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn buildSandbox(b: *Build, target: Target, optimize: Optimize, imports: Imports) *Build.Step.Compile {
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
    return exe;
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

fn linkBgfx(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, runtime: *std.Build.Module) !void {
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
                .path = b.path("src/renderer/shaders/fs_basic.sc"),
            },
            .{
                .name = "vs_basic",
                .shaderType = .vertex,
                .path = b.path("src/renderer/shaders/vs_basic.sc"),
            },
        },
    );
    runtime.addImport("shader_module", shaders_module);
}
