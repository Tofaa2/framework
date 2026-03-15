const std = @import("std");

pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("window-plugin", .{
        .root_source_file = b.path("plugins/window/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
