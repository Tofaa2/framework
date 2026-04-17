const std = @import("std");
const rgfw = @import("rgfw");
const math = @import("math");
const renderer = @import("renderer");

const RenderWorld = renderer.RenderWorld;
const Camera = renderer.Camera;
const MeshLoader = renderer.MeshLoader;
const Material = renderer.Material;
const RenderGraph = renderer.RenderGraph;
const bgfx = renderer.bgfx;
const ShaderProgram = renderer.ShaderProgram;

const MOVE_SPEED: f32 = 10.0;
const MOUSE_SENS: f32 = 0.002;
const NUM_BLUR_PASSES: u32 = 4;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var window = try allocator.create(rgfw.Window);
    defer allocator.destroy(window);
    try window.init("RenderGraph Bloom Test", 1280, 720);
    defer window.deinit();

    std.log.info("RenderGraph Bloom Test - Space: toggle, Up/Down: intensity, 1-3: threshold, 4-6: blur passes", .{});

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

    var graph = try RenderGraph.init(allocator, 1280, 720);
    defer graph.deinit();

    try graph.addExternal("scene", rw.getSceneTexture().?);
    try graph.addExternal("depth", rw.getDepthTexture().?);
    try graph.addInternal("bright", .half);
    try graph.addInternal("blur_a", .half);
    try graph.addInternal("blur_b", .half);

    const threshold_prog = try ShaderProgram.initFromMem(
        renderer.shaders.vs_fullscreen.getShaderForRenderer(rt),
        renderer.shaders.fs_bloom_threshold.getShaderForRenderer(rt),
    );
    const blur_prog = try ShaderProgram.initFromMem(
        renderer.shaders.vs_fullscreen.getShaderForRenderer(rt),
        renderer.shaders.fs_bloom_blur.getShaderForRenderer(rt),
    );
    const composite_prog = try ShaderProgram.initFromMem(
        renderer.shaders.vs_fullscreen.getShaderForRenderer(rt),
        renderer.shaders.fs_bloom_composite.getShaderForRenderer(rt),
    );

    try graph.addPass(.{
        .name = "threshold",
        .program = threshold_prog,
        .inputs = &.{"scene"},
        .output = "bright",
        .input_samplers = &.{"s_graphInput0"},
        .bind_fn = thresholdBind,
    });

    var prevBlur: []const u8 = "bright";
    var blurIter: u32 = 0;
    while (blurIter < NUM_BLUR_PASSES) : (blurIter += 1) {
        const is_even = blurIter % 2 == 0;
        const h_out = if (is_even) "blur_a" else "blur_b";
        const v_out = if (blurIter == NUM_BLUR_PASSES - 1) "blur_b" else if (is_even) "blur_b" else "blur_a";

        try graph.addPass(.{
            .name = try std.fmt.allocPrint(allocator, "blur_h_{}", .{blurIter}),
            .program = blur_prog,
            .inputs = &.{prevBlur},
            .output = h_out,
            .input_samplers = &.{"s_graphInput0"},
            .bind_fn = blurHBind,
        });

        try graph.addPass(.{
            .name = try std.fmt.allocPrint(allocator, "blur_v_{}", .{blurIter}),
            .program = blur_prog,
            .inputs = &.{h_out},
            .output = v_out,
            .input_samplers = &.{"s_graphInput0"},
            .bind_fn = blurVBind,
        });

        prevBlur = v_out;
    }

    const finalBlur = if (NUM_BLUR_PASSES % 2 == 0) "blur_a" else "blur_b";

    try graph.addPass(.{
        .name = "composite",
        .program = composite_prog,
        .inputs = &.{ "scene", finalBlur },
        .input_samplers = &.{ "s_graphInput0", "s_graphInput1" },
        .bind_fn = compositeBind,
    });

    try graph.compile();

    bloom_state.enabled = true;
    bloom_state.threshold = 0.5;
    bloom_state.intensity = 1.0;

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
                    if (kp.key == .space) {
                        bloom_state.enabled = !bloom_state.enabled;
                        std.log.info("Bloom: {}", .{bloom_state.enabled});
                    }
                    if (kp.key == .up) bloom_state.intensity += 0.25;
                    if (kp.key == .down) bloom_state.intensity -= 0.25;
                    if (kp.key == .@"1") bloom_state.threshold = 0.3;
                    if (kp.key == .@"2") bloom_state.threshold = 0.5;
                    if (kp.key == .@"3") bloom_state.threshold = 0.7;
                    if (kp.key == .@"4") std.log.info("Blur passes: 1", .{});
                    if (kp.key == .@"5") std.log.info("Blur passes: 2", .{});
                    if (kp.key == .@"6") std.log.info("Blur passes: 4", .{});
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

        if (bloom_state.enabled) {
            graph.run(rw.getUniforms(), null);
        }

        rw.endFrame();
    }
}

const BloomState = struct {
    enabled: bool,
    threshold: f32,
    intensity: f32,
};

var bloom_state = BloomState{ .enabled = true, .threshold = 0.5, .intensity = 1.0 };

fn thresholdBind(
    enc: renderer.DrawEncoder,
    uniforms: *renderer.UniformStore,
    pass_index: u32,
) void {
    _ = pass_index;
    const h_threshold = uniforms.getOrCreate("u_threshold", bgfx.UniformType.Vec4, 1);
    const params = math.Vec4{ .x = bloom_state.threshold, .y = 0, .z = 0, .w = 0 };
    enc.setVec4(h_threshold, &params);
}

fn blurHBind(
    enc: renderer.DrawEncoder,
    uniforms: *renderer.UniformStore,
    pass_index: u32,
) void {
    _ = pass_index;
    const h_blur = uniforms.getOrCreate("u_blurParams", bgfx.UniformType.Vec4, 1);
    const params = math.Vec4{ .x = 1.0, .y = 0.0, .z = 1.0, .w = 0 };
    enc.setVec4(h_blur, &params);
}

fn blurVBind(
    enc: renderer.DrawEncoder,
    uniforms: *renderer.UniformStore,
    pass_index: u32,
) void {
    _ = pass_index;
    const h_blur = uniforms.getOrCreate("u_blurParams", bgfx.UniformType.Vec4, 1);
    const params = math.Vec4{ .x = 0.0, .y = 1.0, .z = 1.0, .w = 0 };
    enc.setVec4(h_blur, &params);
}

fn compositeBind(
    enc: renderer.DrawEncoder,
    uniforms: *renderer.UniformStore,
    pass_index: u32,
) void {
    _ = pass_index;
    const h_bloom = uniforms.getOrCreate("u_bloomIntensity", bgfx.UniformType.Vec4, 1);
    const params = math.Vec4{ .x = bloom_state.intensity, .y = 0, .z = 0, .w = 0 };
    enc.setVec4(h_bloom, &params);
}
