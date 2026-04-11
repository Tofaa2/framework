const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.addModule("pool", .{
        .root_source_file = b.path("pool/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
