const std = @import("std");

pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("dyn", .{
        .root_source_file = b.path("libs/dyn/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
