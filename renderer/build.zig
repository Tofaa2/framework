const std = @import("std");
const zbgfx = @import("zbgfx");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, pool: *std.Build.Module) *std.Build.Module {
    const module = b.addModule("renderer", .{
        .root_source_file = b.path("renderer/src/Renderer.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    module.addImport("pool", pool);

    const zmesh = b.dependency("zmesh", .{});
    module.addImport("zmesh", zmesh.module("root"));
    module.linkLibrary(zmesh.artifact("zmesh"));

    linkBgfx(b, target, optimize, module) catch unreachable;
    return module;
}

fn linkBgfx(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, runtime: *std.Build.Module) !void {
    _ = optimize;
    const zbgfx_dep = b.dependency("zbgfx", .{
        .multithread = false,
    });
    runtime.addImport("bgfx", zbgfx_dep.module("zbgfx"));
    runtime.linkLibrary(zbgfx_dep.artifact("bgfx"));

    const install_shaderc_step = try zbgfx.build_step.installShaderc(b, zbgfx_dep);
    const shaders_includes = &.{ b.path("renderer/src/shaders"), zbgfx_dep.path("shaders") };
    const shaders_module = try zbgfx.build_step.compileShaders(
        b,
        target,
        install_shaderc_step,
        zbgfx_dep,
        shaders_includes,
        &.{
            .{
                .name = "fs_cubes",
                .shaderType = .fragment,
                .path = b.path("renderer/src/shaders/fs_cubes.sc"),
            },
            .{
                .name = "vs_cubes",
                .shaderType = .vertex,
                .path = b.path("renderer/src/shaders/vs_cubes.sc"),
            },
        },
    );
    runtime.addImport("shader_module", shaders_module);
}
