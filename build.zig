const std = @import("std");

const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "framework",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    }); 
    const framework = b.addModule("framework", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize
    });


    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    lib.linkLibrary(raylib_artifact);
    lib.root_module.addImport("raylib", raylib);
    lib.root_module.addImport("raygui", raygui);

    framework.linkLibrary(raylib_artifact);
    framework.addImport("raylib", raylib);
    framework.addImport("raygui", raygui);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
