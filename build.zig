const std = @import("std");
const Build = *std.Build;
const Optimize = std.builtin.OptimizeMode;
const Target = std.Build.ResolvedTarget;
const Module = *std.Build.Module;

const zig_bgfx = @import("zig_bgfx");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const runtime_mod = b.addModule("runtime", .{
        .root_source_file = b.path("runtime/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    runtime_mod.addIncludePath(b.path("include/"));
    runtime_mod.addCSourceFile(.{ .file = b.path("runtime/c/stb_impl.c") });

    linkSimpleModDep(b, runtime_mod, "entt", "ecs", "zig-ecs");
    linkSimpleModDep(b, runtime_mod, "zigwin32", "win32", "win32");
    linkBgfx(b, .{
        .path = "runtime/renderer/shader/",
        .install_subdir = "renderer-shaders",
        .import_name = "renderer-shaders",
    }, runtime_mod, target, optimize);

    const exe = b.addExecutable(.{
        .name = "framework-sandbox",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sandbox/main.zig"),
            .imports = &.{
                .{
                    .name = "framework-runtime",
                    .module = runtime_mod,
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

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

fn linkBgfx(
    b: Build,
    shader: ?struct {
        path: []const u8,
        import_name: []const u8,
        install_subdir: []const u8,
    },
    module: Module,
    target: Target,
    optimize: Optimize,
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
