const std = @import("std");
const zig_bgfx = @import("zig_bgfx");

pub fn build(b: *std.Build) !void {
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

    const math = makeModule(b, test_step, "framework-math", "src/math/root.zig", &.{}, target, optimize);

    const renderer = makeModule(b, test_step, "framework-renderer", "src/renderer/root.zig", &.{
        .{
            .name = "utils",
            .module = utils,
        },
        .{
            .name = "math",
            .module = math,
        },
    }, target, optimize);
    linkSimpleModDep(b, renderer, "zigwin32", "win32", "win32");
    linkBgfx(b, .{
        .path = "src/renderer/shader/",
        .install_subdir = "renderer-shaders",
        .import_name = "renderer-shaders",
    }, renderer, target, optimize);
    renderer.addIncludePath(b.path("thirdparty/stb/"));

    const exe = b.addExecutable(.{
        .name = "framework-sandbox",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sandbox/main.zig"),
            .imports = &.{
                .{
                    .name = "framework",
                    .module = app_sdk,
                },
                .{
                    .name = "window",
                    .module = window,
                },
                .{
                    .name = "renderer",
                    .module = renderer,
                },
            },

            .optimize = optimize,
            .target = target,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    exe.use_llvm = true;
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
fn linkSimpleModDepWithArtifact(b: *std.Build, module: *std.Build.Module, dep_name: []const u8, name: []const u8, mod_name: []const u8, artifact: []const u8) void {
    const dep = b.dependency(dep_name, .{});
    const mod = dep.module(mod_name);
    module.addImport(name, mod);
    module.linkLibrary(dep.artifact(artifact));
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

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

fn linkBgfx(
    b: *std.Build,
    shader: ?struct {
        path: []const u8,
        import_name: []const u8,
        install_subdir: []const u8,
    },
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    _ = optimize;
    // link BGFX
    const bgfx = b.dependency("zig_bgfx", .{
        .target = target,
        .optimize = .ReleaseFast,
        // example: disable DirectX 12 support
        .directx12 = true,
        // example: set supported OpenGL version (GLSL 1.4 used below is only supported since OpenGL 3.1)
        .@"opengl-version" = 31,
    });

    module.linkLibrary(bgfx.artifact("bgfx"));
    if (shader != null) {
        // compile shaders
        const shader_dir = zig_bgfx.buildShaderDir(b, .{
            .target = target.result,
            .root_path = shader.?.path, //"shaders",
            .backend_configs = &.{
                .{ .name = "opengl", .shader_model = .@"140", .supported_platforms = &.{ .windows, .linux } },
                .{ .name = "vulkan", .shader_model = .spirv, .supported_platforms = &.{ .windows, .linux } },
                .{ .name = "directx", .shader_model = .s_5_0, .supported_platforms = &.{.windows} },
                .{ .name = "metal", .shader_model = .metal, .supported_platforms = &.{.macos} },
            },
        }) catch {
            @panic("failed to compile all shaders in path 'shaders'");
        };

        for (shader_dir.backend_names) |name| {
            std.debug.print("Compiling shader backend {s}\n", .{name});
        }

        // create a module to embed directly shaders in zig code
        module.addAnonymousImport(shader.?.import_name, .{
            .root_source_file = zig_bgfx.createShaderModule(b, shader_dir) catch {
                std.debug.panic("failed to create shader module from path 'shaders'", .{});
            },
        });

        // install compiled shaders in zig-out
        const shader_dir_install = b.addInstallDirectory(.{
            .source_dir = shader_dir.files.getDirectory(),
            .install_dir = .prefix,
            .install_subdir = shader.?.install_subdir, //  shader.?.install_subdir, //  "my_shader_dir",
        });
        // shader_dir_install.step.dependOn(&shader_dir.files.step); // explicit dependency
        b.getInstallStep().dependOn(&shader_dir_install.step);
        // exe.step.dependOn(&shader_dir_install.step);
    }
}
