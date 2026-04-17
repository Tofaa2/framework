const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    return b.addLibrary(.{
        .name = "math",
        .root_module = b.createModule(.{
            .root_source_file = b.path("math/src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
}
