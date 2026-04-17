const std = @import("std");
const rgfw = @import("rgfw");
const math = @import("math");
const renderer = @import("renderer");

const RenderWorld = renderer.RenderWorld;
const Camera = renderer.Camera;
const Material = renderer.Material;
const Mesh = renderer.Mesh;
const MeshLoader = renderer.MeshLoader;
const Texture = renderer.Texture;

const MOVE_SPEED: f32 = 5.0;
const SPRINT_MULT: f32 = 2.5;
const MOUSE_SENS: f32 = 0.002;

const PbrDemoConfig = struct {
    name: []const u8,
    albedo: math.Vec4,
    metallic: f32,
    roughness: f32,
    albedo_path: []const u8 = "",
    metallic_roughness_path: []const u8 = "",
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var window = try allocator.create(rgfw.Window);
    defer allocator.destroy(window);
    try window.init("Sandbox — Orin Renderer", 1280, 720);
    defer window.deinit();

    var rw = try RenderWorld.init(allocator, .{
        .nwh = window.getNativePtr(),
        .ndt = window.getNativeNdt(),
        .width = 1280,
        .height = 720,
        .debug = false,
    });
    defer rw.deinit();

    var camera = Camera.fps(
        math.Vec3.new(0, 8, -25),
        math.Vec3.new(0, 2, 0),
        1280.0 / 720.0,
    );
    var cam = camera.perspectiveRef();

    rw.addLight(.{
        .dir = .{
            .direction = math.Vec3.new(0.5, -1, 0.3),
            .color = .{ .x = 1, .y = 0.95, .z = 0.9 },
            .intensity = 1.5,
        },
    });

    var helmet_model = MeshLoader.load(allocator, "assets/models/DamagedHelmet.glb", .{ .center = true, .scale = 40.0 }) catch |e| {
        std.log.info("[sandbox] Helmet error: {}", .{e});
        return;
    };
    defer helmet_model.deinit();

    const pbr_configs = [_]PbrDemoConfig{
        .{ .name = "Metal007 (Gold/Steel)", .albedo = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, .metallic = 0.0, .roughness = 0.0, .albedo_path = "assets/textures/Metal007/Metal007_1K-JPG_Color.jpg", .metallic_roughness_path = "assets/textures/Metal007/Metal007_1K-JPG" },
        .{ .name = "Metal008", .albedo = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, .metallic = 0.0, .roughness = 0.0, .albedo_path = "assets/textures/Metal008/Metal008_1K-JPG_Color.jpg", .metallic_roughness_path = "assets/textures/Metal008/Metal008_1K-JPG" },
        .{ .name = "Metal009", .albedo = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 }, .metallic = 0.0, .roughness = 0.0, .albedo_path = "assets/textures/Metal009/Metal009_1K-JPG_Color.jpg", .metallic_roughness_path = "assets/textures/Metal009/Metal009_1K-JPG" },
        .{ .name = "Gold (Metallic)", .albedo = .{ .x = 1.0, .y = 0.78, .z = 0.34, .w = 1.0 }, .metallic = 1.0, .roughness = 0.2 },
        .{ .name = "Copper", .albedo = .{ .x = 0.95, .y = 0.64, .z = 0.54, .w = 1.0 }, .metallic = 1.0, .roughness = 0.3 },
        .{ .name = "Steel", .albedo = .{ .x = 0.6, .y = 0.6, .z = 0.65, .w = 1.0 }, .metallic = 1.0, .roughness = 0.4 },
        .{ .name = "Plastic (Red)", .albedo = .{ .x = 0.9, .y = 0.15, .z = 0.15, .w = 1.0 }, .metallic = 0.0, .roughness = 0.4 },
        .{ .name = "Rubber (Black)", .albedo = .{ .x = 0.05, .y = 0.05, .z = 0.05, .w = 1.0 }, .metallic = 0.0, .roughness = 0.9 },
        .{ .name = "Wood (Oak)", .albedo = .{ .x = 0.6, .y = 0.4, .z = 0.2, .w = 1.0 }, .metallic = 0.0, .roughness = 0.6 },
    };

    var sphere_mesh = MeshLoader.createSphere(allocator, 2.5, 32, 24) catch |e| {
        std.log.info("[sandbox] Failed to create sphere: {}", .{e});
        return;
    };
    defer sphere_mesh.deinit();

    var pbr_textures: [3]struct { albedo: ?Texture = null, metallic_roughness: ?Texture = null } = .{ .{}, .{}, .{} };

    if (pbr_configs[0].albedo_path.len > 0) {
        pbr_textures[0].albedo = Texture.initFromFile("assets/textures/Metal007/Metal007_1K-JPG_Color.jpg") catch null;
        pbr_textures[0].metallic_roughness = Texture.initFromFile("assets/textures/Metal007/Metal007_1K-JPG_Metalness.jpg") catch null;
    }
    if (pbr_configs[1].albedo_path.len > 0) {
        pbr_textures[1].albedo = Texture.initFromFile("assets/textures/Metal008/Metal008_1K-JPG_Color.jpg") catch null;
        pbr_textures[1].metallic_roughness = Texture.initFromFile("assets/textures/Metal008/Metal008_1K-JPG_Metalness.jpg") catch null;
    }
    if (pbr_configs[2].albedo_path.len > 0) {
        pbr_textures[2].albedo = Texture.initFromFile("assets/textures/Metal009/Metal009_1K-JPG_Color.jpg") catch null;
        pbr_textures[2].metallic_roughness = Texture.initFromFile("assets/textures/Metal009/Metal009_1K-JPG_Metalness.jpg") catch null;
    }

    var helmet_textures: [2]?Texture = .{ null, null };
    if (helmet_model.submeshes.len > 0) {
        const submesh = helmet_model.submeshes[0];
        if (submesh.material.texture_data) |data| {
            helmet_textures[0] = Texture.initFromMemory(data) catch null;
        }
        if (submesh.material.metallic_roughness_texture_data) |data| {
            helmet_textures[1] = Texture.initFromMemory(data) catch null;
        }
    }
    defer {
        for (0..pbr_textures.len) |i| {
            if (pbr_textures[i].albedo) |*tex| tex.deinit();
            if (pbr_textures[i].metallic_roughness) |*tex| tex.deinit();
        }
        for (0..helmet_textures.len) |i| {
            if (helmet_textures[i]) |*tex| tex.deinit();
        }
    }

    var time: f32 = 0;
    var timer = try std.time.Timer.start();
    _ = timer.lap();

    while (!window.shouldClose()) {
        if (timer.read() > 300_000_000_000) return; // 5 minutes

        const dt: f32 = @as(f32, @floatFromInt(timer.lap())) / @as(f32, 1_000_000_000);

        while (window.pollEvent()) |ev| {
            switch (ev) {
                .quit => return,
                .key_pressed => |kp| {
                    if (kp.key == .escape) return;
                    switch (kp.key) {
                        .@"1" => rw.setAaMode(.none),
                        .@"2" => rw.setAaMode(.msaa2x),
                        .@"3" => rw.setAaMode(.msaa4x),
                        .@"4" => rw.setAaMode(.msaa8x),
                        .@"5" => rw.setAaMode(.msaa16x),
                        else => {},
                    }
                },
                .mouse_button_pressed => |mb| {
                    if (mb.button == .left) window.setMouseCaptured(true);
                },
                .focus_out => window.setMouseCaptured(false),
                .window_resized => |sz| {
                    rw.resize(sz[0], sz[1]);
                    const aspect: f32 = @as(f32, @floatFromInt(sz[0])) / @as(f32, @floatFromInt(sz[1]));
                    cam.setAspect(aspect);
                },
                else => {},
            }
        }

        const dx = window.mouse_delta_x;
        const dy = window.mouse_delta_y;
        window.mouse_delta_x = 0;
        window.mouse_delta_y = 0;

        if (dx != 0 or dy != 0) {
            cam.lookFromMouse(dx, dy, MOUSE_SENS);
        }

        const speed = MOVE_SPEED * (if (window.isKeyDown(.shiftL) or window.isKeyDown(.shiftR)) SPRINT_MULT else 1.0) * dt;

        if (window.isKeyDown(.w) or window.isKeyDown(.up)) cam.moveForward(speed);
        if (window.isKeyDown(.s) or window.isKeyDown(.down)) cam.moveForward(-speed);
        if (window.isKeyDown(.d) or window.isKeyDown(.right)) cam.moveRight(speed);
        if (window.isKeyDown(.a) or window.isKeyDown(.left)) cam.moveRight(-speed);
        if (window.isKeyDown(.space)) cam.moveUp(speed);
        if (window.isKeyDown(.controlL)) cam.moveUp(-speed);

        rw.setCamera3D(camera);

        time += dt;

        rw.beginFrame();

        const grid_size: i32 = 3;
        const spacing: f32 = 14.0;
        const grid_offset = @as(f32, @floatFromInt(grid_size - 1)) * spacing * 0.5;

        for (0..@as(usize, @intCast(grid_size * grid_size))) |i| {
            const col: i32 = @mod(@as(i32, @intCast(i)), grid_size);
            const row: i32 = @divTrunc(@as(i32, @intCast(i)), grid_size);

            const x = @as(f32, @floatFromInt(col)) * spacing - grid_offset;
            const z = @as(f32, @floatFromInt(row)) * spacing - grid_offset;
            const bob = @sin(time * 1.5 + @as(f32, @floatFromInt(i)) * 0.4) * 0.3;

            const transform = math.Mat4.translation(x, bob, z);

            if (i < pbr_configs.len) {
                const cfg = pbr_configs[i];
                var mat = Material.pbr(cfg.albedo, cfg.metallic, cfg.roughness);

                if (i < pbr_textures.len and pbr_textures[i].albedo != null) {
                    mat.kind.pbr.textures.albedo = &pbr_textures[i].albedo.?;
                }
                if (i < pbr_textures.len and pbr_textures[i].metallic_roughness != null) {
                    mat.kind.pbr.textures.metallic_roughness = &pbr_textures[i].metallic_roughness.?;
                }

                rw.drawMesh(&sphere_mesh, mat, transform);
            }
        }

        const helmet_x: f32 = @sin(time * 0.4) * 25;
        const helmet_z: f32 = @cos(time * 0.4) * 25;
        const helmet_y: f32 = 18.0 + @sin(time * 1.0) * 3.0;
        const helmet_rot = time * 0.6;

        var helmet_transform = math.Mat4.translation(helmet_x, helmet_y, helmet_z);
        helmet_transform = math.Mat4.mul(helmet_transform, math.Mat4.rotationY(helmet_rot));
        helmet_transform = math.Mat4.mul(helmet_transform, math.Mat4.rotationX(-0.2));

        for (helmet_model.submeshes) |submesh| {
            var pbr_mat = Material.pbr(submesh.material.diffuse, 0.3, 0.4);

            if (helmet_textures[0]) |*tex| {
                pbr_mat.kind.pbr.textures.albedo = tex;
            }
            if (helmet_textures[1]) |*tex| {
                pbr_mat.kind.pbr.textures.metallic_roughness = tex;
            }

            rw.drawMesh(&submesh.mesh, pbr_mat, helmet_transform);
        }

        rw.endFrame();
    }
}
