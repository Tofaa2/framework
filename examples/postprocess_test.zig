const std = @import("std");
const rgfw = @import("rgfw");
const math = @import("math");
const renderer = @import("renderer");

const RenderWorld = renderer.RenderWorld;
const Camera = renderer.Camera;
const MeshLoader = renderer.MeshLoader;
const Material = renderer.Material;
const PostProcess = renderer.PostProcess;
const bgfx = renderer.bgfx;
const ShaderProgram = renderer.ShaderProgram;

const MOVE_SPEED: f32 = 10.0;
const MOUSE_SENS: f32 = 0.002;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var window = try allocator.create(rgfw.Window);
    defer allocator.destroy(window);
    try window.init("Tone Mapping Test", 1280, 720);
    defer window.deinit();

    std.log.info("Tone Mapping Test - 1: ACES, 2: Reinhard, 3: No tonemap", .{});

    var rw = try RenderWorld.init(allocator, .{
        .nwh = window.getNativePtr(),
        .ndt = window.getNativeNdt(),
        .width = 1280,
        .height = 720,
        .debug = false,
        .post_process = true,
    });
    defer rw.deinit();

    var camera = Camera.fps(
        math.Vec3.new(0, 3, -8),
        math.Vec3.new(0, 0, 0),
        1280.0 / 720.0,
    );

    rw.addLight(.{
        .dir = .{
            .direction = math.Vec3.new(0.5, -1, 0.5),
            .color = .{ .x = 1.0, .y = 0.95, .z = 0.85 },
            .intensity = 5.0,
        },
    });

    var sphere = try MeshLoader.createSphere(allocator, 1.0, 32, 32);
    defer sphere.deinit();

    const gold = Material.pbr(.{ .x = 1.0, .y = 0.78, .z = 0.34, .w = 1.0 }, 1.0, 0.2);
    const copper = Material.pbr(.{ .x = 0.95, .y = 0.64, .z = 0.54, .w = 1.0 }, 1.0, 0.3);
    const silver = Material.pbr(.{ .x = 0.95, .y = 0.93, .z = 0.88, .w = 1.0 }, 1.0, 0.1);
    const red_mat = Material.pbr(.{ .x = 1.0, .y = 0.1, .z = 0.1, .w = 1.0 }, 0.0, 0.5);
    const green_mat = Material.pbr(.{ .x = 0.1, .y = 1.0, .z = 0.1, .w = 1.0 }, 0.0, 0.5);
    const blue_mat = Material.pbr(.{ .x = 0.1, .y = 0.1, .z = 1.0, .w = 1.0 }, 0.0, 0.5);
    const materials = [_]Material{ gold, copper, silver, red_mat, green_mat, blue_mat };

    const rt = bgfx.getRendererType();

    var post = try PostProcess.init(allocator);
    defer post.deinit();

    if (rw.getSceneTexture()) |scene_tex| {
        const prog = try ShaderProgram.initFromMem(
            renderer.shaders.vs_fullscreen.getShaderForRenderer(rt),
            renderer.shaders.fs_tonemap.getShaderForRenderer(rt),
        );
        try post.addPass(.{
            .program = prog,
            .input = scene_tex,
            .bind_fn = tonemapBind,
        });
    }
    rw.setPostProcess(&post);

    var time: f32 = 0.0;
    var timer = try std.time.Timer.start();
    _ = timer.lap();

    while (!window.shouldClose()) {
        if (timer.read() > 600_000_000_000) return;

        const dt: f32 = @as(f32, @floatFromInt(timer.lap())) / @as(f32, 1_000_000_000);
        time += dt;

        while (window.pollEvent()) |ev| {
            switch (ev) {
                .quit => return,
                .key_pressed => |kp| {
                    if (kp.key == .escape) return;
                    if (kp.key == .@"1") {
                        tonemap_state.mode = 0.0;
                    }
                    if (kp.key == .@"2") {
                        tonemap_state.mode = 1.0;
                    }
                    if (kp.key == .@"3") {
                        tonemap_state.mode = 2.0;
                    }
                    if (kp.key == .up) tonemap_state.exposure += 0.5;
                    if (kp.key == .down) tonemap_state.exposure -= 0.5;
                },
                else => {},
            }
        }

        const dx = window.mouse_delta_x;
        const dy = window.mouse_delta_y;
        window.mouse_delta_x = 0;
        window.mouse_delta_y = 0;

        if (dx != 0 or dy != 0) {
            camera.perspectiveRef().lookFromMouse(dx, dy, MOUSE_SENS);
        }

        const speed = MOVE_SPEED * dt;
        if (window.isKeyDown(.w)) camera.perspectiveRef().moveForward(speed);
        if (window.isKeyDown(.s)) camera.perspectiveRef().moveForward(-speed);

        rw.setCamera3D(camera);

        rw.beginFrame();

        for (materials, 0..) |mat, i| {
            const angle = @as(f32, @floatFromInt(i)) * std.math.pi * 2.0 / @as(f32, @floatFromInt(materials.len));
            const x = @cos(angle) * 4.0;
            const z = @sin(angle) * 4.0;
            const transform = math.Mat4.translation(x, 0, z);
            rw.drawMesh(&sphere, mat, transform);
        }

        rw.endFrame();

        std.log.info("Mode: {d:.1}, Exposure: {d:.2}", .{ tonemap_state.mode, tonemap_state.exposure });
    }
}

const TonemapState = struct {
    mode: f32,
    exposure: f32,
};

var tonemap_state = TonemapState{ .mode = 0.0, .exposure = 1.0 };

fn tonemapBind(
    enc: renderer.DrawEncoder,
    uniforms: *renderer.UniformStore,
    pass_index: u32,
) void {
    _ = pass_index;
    const h_tonemap = uniforms.vec4("u_tonemapParams");
    const params = math.Vec4{ .x = 3.0, .y = tonemap_state.mode, .z = 2.2, .w = 0 };
    enc.setVec4(h_tonemap, &params);
}
