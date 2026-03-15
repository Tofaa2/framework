const std = @import("std");

pub fn apply(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.addModule("window", .{
        .root_source_file = b.path("libs/window/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    switch (target.result.os.tag) {
        .windows => {
            module.linkSystemLibrary("gdi32", .{ .needed = true });
        },
        else => {},
    }

    module.addIncludePath(b.path("libs/window/src"));
    module.addCSourceFile(.{ .file = b.path("libs/window/src/RGFW_Impl.c") });
    return module;
}
