const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests");

    const utils = makeModule(b, test_step, "framework-utils", "src/utils/root.zig", &.{}, target, optimize);
    const scheduler = makeModule(b, test_step, "framework-scheduler", "src/scheduler/root.zig", &.{}, target, optimize);
    const resources = makeModule(b, test_step, "framework-resources", "src/resources/root.zig", &.{
        .{
            .name = "utils",
            .module = utils,
        },
    }, target, optimize);

    const plugin = makeModule(b, test_step, "framework-plugin", "src/plugin/root.zig", &.{.{
        .name = "utils",
        .module = utils,
    }}, target, optimize);

    const app_sdk = makeModule(b, test_step, "framework-app-sdk", "src/app-sdk/root.zig", &.{}, target, optimize);
    linkSimpleModDep(b, app_sdk, "entt", "ecs", "zig-ecs");
    app_sdk.addImport("utils", utils);
    app_sdk.addImport("plugin", plugin);
    app_sdk.addImport("scheduler", scheduler);
    app_sdk.addImport("resources", resources);

    const window = makeModule(b, test_step, "framework-window", "src/window/root.zig", &.{}, target, optimize);
    linkSimpleModDep(b, window, "zigwin32", "win32", "win32");

    const exe = b.addExecutable(.{
        .name = "framework-sandbox",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sandbox/main.zig"),
            .imports = &.{ .{
                .name = "framework",
                .module = app_sdk,
            }, .{
                .name = "window",
                .module = window,
            } },
            .optimize = optimize,
            .target = target,
        }),
    });

    b.installArtifact(exe);

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn linkSimpleModDep(b: *std.Build, module: *std.Build.Module, dep_name: []const u8, name: []const u8, mod_name: []const u8) void {
    const dep = b.dependency(dep_name, .{});
    const mod = dep.module(mod_name);
    module.addImport(name, mod);
}

fn makeModule(
    b: *std.Build,
    tests: *std.Build.Step,
    name: []const u8,
    path: []const u8,
    imports: []const std.Build.Module.Import,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path(path),
        .imports = imports,
    });

    const module_tests = b.addTest(.{
        .root_module = mod,
        //.root_source_file = b.path(mod_info.path),
    });
    // module_tests.linkLibC();
    // module_tests.addIncludePath(b.path("includes/"));

    const run_module_tests = b.addRunArtifact(module_tests);
    tests.dependOn(&run_module_tests.step);
    return mod;
}

fn makeAppSdkPlugin(
    b: *std.Build,
    tests: *std.Build.Step,
    name: []const u8,
    path: []const u8,
    imports: []const std.Build.Module.Import,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    app_sdk: *std.Build.Module,
) *std.Build.Module {
    const mod = makeModule(b, tests, name, path, imports, target, optimize);
    mod.addImport("app-sdk", app_sdk);
    return mod;
}
