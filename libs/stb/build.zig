const std = @import("std");

pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.addModule("stb", .{
        .link_libc = true,
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("libs/stb/src/root.zig"),
    });
    module.addIncludePath(b.path("libs/stb/src/"));
    module.addCSourceFiles(.{
        .files = &.{
            "stb_truetype_impl.c",
        },
        .root = b.path("libs/stb/src/"),
        .language = .c,
    });

    return module;
}
