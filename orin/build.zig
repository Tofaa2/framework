const std = @import("std");

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    ecs_mod: *std.Build.Module,
) *std.Build.Module {
    const orin_mod = b.addModule("orin", .{
        .root_source_file = b.path("orin/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    orin_mod.addImport("ecs", ecs_mod);
    return orin_mod;
}
