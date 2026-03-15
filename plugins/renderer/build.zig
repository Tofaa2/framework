const std = @import("std");
const zbgfx = @import("zbgfx");
pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const mod = b.addModule("renderer-plugin", .{
        .root_source_file = b.path("plugins/renderer/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "window", .module = b.modules.get("window-plugin").? },
            .{ .name = "runtime", .module = b.modules.get("runtime").? },
        },
    });
    linkBgfx(b, target, optimize, mod) catch unreachable;

    return mod;
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
                .path = b.path("plugins/renderer/shaders/fs_basic.sc"),
            },
            .{
                .name = "vs_basic",
                .shaderType = .vertex,
                .path = b.path("plugins/renderer/shaders/vs_basic.sc"),
            },
        },
    );
    runtime.addImport("shader_module", shaders_module);
}
