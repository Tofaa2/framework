const std = @import("std");
const zbgfx = @import("zbgfx");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.addModule("renderer", .{
        .root_source_file = b.path("renderer/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    linkBgfx(b, target, optimize, module) catch unreachable;
    return module;
}

fn linkBgfx(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, runtime: *std.Build.Module) !void {
    _ = optimize;
    _ = target;
    const zbgfx_dep = b.dependency("zbgfx", .{});
    runtime.addImport("bgfx", zbgfx_dep.module("zbgfx"));
    runtime.linkLibrary(zbgfx_dep.artifact("bgfx"));
    // const install_shaderc_step = try zbgfx.build_step.installShaderc(b, zbgfx_dep);
    // const shaders_includes = &.{zbgfx_dep.path("shaders")};
    // const shaders_module = try zbgfx.build_step.compileShaders(
    //     b,
    //     target,
    //     install_shaderc_step,
    //     zbgfx_dep,
    //     shaders_includes,
    //     &.{
    //         .{
    //             .name = "fs_basic",
    //             .shaderType = .fragment,
    //             .path = b.path("src/renderer/shaders/fs_basic.sc"),
    //         },
    //         .{
    //             .name = "vs_basic",
    //             .shaderType = .vertex,
    //             .path = b.path("src/renderer/shaders/vs_basic.sc"),
    //         },
    //         .{
    //             .name = "fs_diffuse",
    //             .shaderType = .fragment,
    //             .path = b.path("src/renderer/shaders/fs_diffuse.sc"),
    //         },
    //         .{
    //             .name = "vs_skybox",
    //             .shaderType = .vertex,
    //             .path = b.path("src/renderer/shaders/skybox/vs_skybox.sc"),
    //         },
    //         .{
    //             .name = "fs_skybox",
    //             .shaderType = .fragment,
    //             .path = b.path("src/renderer/shaders/skybox/fs_skybox.sc"),
    //         },
    //         .{
    //             .name = "vs_diffuse",
    //             .shaderType = .vertex,
    //             .path = b.path("src/renderer/shaders/vs_diffuse.sc"),
    //         },
    //     },
    // );
    // runtime.addImport("shader_module", shaders_module);
}
