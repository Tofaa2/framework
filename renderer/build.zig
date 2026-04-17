const std = @import("std");
const zbgfx = @import("zbgfx");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, pool: *std.Build.Module, math: *std.Build.Module, stb: *std.Build.Step.Compile) *std.Build.Module {
    const module = b.addModule("renderer", .{
        .root_source_file = b.path("renderer/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    module.addImport("pool", pool);
    module.addImport("math", math);

    // zmesh for OBJ/GLTF loading
    const zmesh = b.dependency("zmesh", .{});
    module.addImport("zmesh", zmesh.module("root"));
    module.linkLibrary(zmesh.artifact("zmesh"));

    // stb for texture loading — passed in from the root build
    module.addImport("stb", stb.root_module);
    module.linkLibrary(stb);

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
            // Legacy example (kept for reference)
            .{ .name = "vs_cubes", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_cubes.sc") },
            .{ .name = "fs_cubes", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_cubes.sc") },
            // Unlit
            .{ .name = "vs_unlit", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_unlit.sc") },
            .{ .name = "fs_unlit", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_unlit.sc") },
            // Blinn-Phong
            .{ .name = "vs_blinn_phong", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_blinn_phong.sc") },
            .{ .name = "fs_blinn_phong", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_blinn_phong.sc") },
            // PBR
            .{ .name = "vs_pbr", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_pbr.sc") },
            .{ .name = "fs_pbr", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_pbr.sc") },
            // 2D sprite batch
            .{ .name = "vs_sprite", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_sprite.sc") },
            .{ .name = "fs_sprite", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_sprite.sc") },
            // Post-processing
            .{ .name = "vs_fullscreen", .shaderType = .vertex, .path = b.path("renderer/src/shaders/vs_fullscreen.sc") },
            .{ .name = "fs_blit", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_blit.sc") },
            .{ .name = "fs_fog", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_fog.sc") },
            .{ .name = "fs_sepia", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_sepia.sc") },
            .{ .name = "fs_debug", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_debug.sc") },
            .{ .name = "fs_bloom", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_bloom.sc") },
            .{ .name = "fs_chromatic", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_chromatic.sc") },
            .{ .name = "fs_tonemap", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_tonemap.sc") },
            .{ .name = "fs_bloom_threshold", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_bloom_threshold.sc") },
            .{ .name = "fs_bloom_blur", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_bloom_blur.sc") },
            .{ .name = "fs_bloom_composite", .shaderType = .fragment, .path = b.path("renderer/src/shaders/fs_bloom_composite.sc") },
        },
    );
    runtime.addImport("shader_module", shaders_module);
}
