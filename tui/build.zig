const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("tui", .{
        .root_source_file = b.path("tui/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
