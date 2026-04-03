const std = @import("std");

pub fn build(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const thirdparty = b.addLibrary(.{ .name = "rgfw", .root_module = b.createModule(.{
        .link_libc = true,
        .root_source_file = b.path("rgfw/src/root.zig"),
        .optimize = optimize,
        .target = target,
    }) });
    thirdparty.addIncludePath(b.path("rgfw/src/"));
    thirdparty.addCSourceFiles(.{
        .files = &.{"rgfw_impl.c"},
        .root = b.path("rgfw/src/"),
    });

    if (b.option(bool, "rgfw_debug", "Enable debug mode") orelse false) {
        thirdparty.root_module.addCMacro("RGFW_DEBUG", "1");
    }

    switch (target.result.os.tag) {
        .windows => {
            thirdparty.linkSystemLibrary("gdi32");
        },
        .linux => {
            thirdparty.linkSystemLibrary("X11");
            thirdparty.linkSystemLibrary("Xrandr");
        },
        .macos => {
            thirdparty.linkFramework("Cocoa");
            thirdparty.linkFramework("CoreVideo");
            thirdparty.linkFramework("IOKit");
        },
        else => {},
    }

    return thirdparty;
}
