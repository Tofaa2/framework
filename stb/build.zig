const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const thirdparty = b.addLibrary(.{ .name = "stb", .root_module = b.createModule(.{
        .link_libc = true,
        .root_source_file = b.path("stb/src/root.zig"),
        .optimize = optimize,
        .target = target,
    }) });
    thirdparty.addIncludePath(b.path("stb/include/"));
    thirdparty.addCSourceFiles(.{
        .files = &.{"stb_impl.c"},
        .root = b.path("stb/src/"),
    });

    return thirdparty;
}
