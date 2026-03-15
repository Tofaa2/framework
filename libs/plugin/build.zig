const std = @import("std");

pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const t_id = b.modules.get("type_id").?;
    return b.addModule("plugin", .{
        .root_source_file = b.path("libs/plugin/src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "type_id",
                .module = t_id,
            },
        },
    });
}
