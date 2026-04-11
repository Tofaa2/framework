const std = @import("std");
const rgfw = @import("rgfw");
const Renderer = @import("renderer");
const zm = Renderer.math;
const math = Renderer.math;
const bgfx = Renderer.bgfx;
const ShaderProgram = Renderer.ShaderProgram;
const shaders = Renderer.default_shaders;
const DrawCall = Renderer.DrawCall;

pub const PosColorVertex = extern struct {
    position: [3]f32,
    color0: [4]f32,
};

pub var cube_vertices = [_]PosColorVertex{
    .{ .position = .{ -1.0, 1.0, 1.0 }, .color0 = .{ 1.0, 0.0, 0.0, 1.0 } },
    .{ .position = .{ 1.0, 1.0, 1.0 }, .color0 = .{ 0.0, 1.0, 0.0, 1.0 } },
    .{ .position = .{ -1.0, -1.0, 1.0 }, .color0 = .{ 0.0, 0.0, 1.0, 1.0 } },
    .{ .position = .{ 1.0, -1.0, 1.0 }, .color0 = .{ 1.0, 1.0, 0.0, 1.0 } },
    .{ .position = .{ -1.0, 1.0, -1.0 }, .color0 = .{ 1.0, 0.0, 1.0, 1.0 } },
    .{ .position = .{ 1.0, 1.0, -1.0 }, .color0 = .{ 0.0, 1.0, 1.0, 1.0 } },
    .{ .position = .{ -1.0, -1.0, -1.0 }, .color0 = .{ 1.0, 1.0, 1.0, 1.0 } },
    .{ .position = .{ 1.0, -1.0, -1.0 }, .color0 = .{ 1.0, 1.0, 1.0, 1.0 } },
};

pub var cube_triangle_list = [_]u16{
    0, 1, 2, // 0
    1, 3, 2,
    4, 6, 5, // 2
    5, 6, 7,
    0, 2, 4, // 4
    4, 2, 6,
    1, 5, 3, // 6
    5, 7, 3,
    0, 4, 1, // 8
    4, 5, 1,
    2, 3, 6, // 10
    6, 3, 7,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var window = try allocator.create(rgfw.Window);
    defer allocator.destroy(window);
    try window.init("Sandbox", 800, 600);
    defer window.deinit();

    Renderer.obj.zmesh.init(allocator);

    var r = try allocator.create(Renderer);
    defer allocator.destroy(r);
    try r.init(.{
        .allocator = allocator,
        .ndt = window.getNativeNdt(),
        .nwh = window.getNativePtr(),
    });
    defer r.deinit();

    // Create view
    var main_view = Renderer.View.init(0, .{
        .x = 0,
        .y = 0,
        .width = 800,
        .height = 600,
    }, Renderer.DrawState.default_3d);
    main_view.clear = .{ .color = 0xFF0000FF, .depth = 1.0 };

    // Create mesh — layout inferred from PosColorVertex field names/types
    const cube_mesh = r.createStaticMesh(
        PosColorVertex,
        .{},
        &cube_vertices,
        &cube_triangle_list,
    );
    _ = cube_mesh;

    const cube_shader = r.createShader(ShaderProgram.initFromMem(
        shaders.vs_cubes.getShaderForRenderer(r.getRendererType()),
        shaders.fs_cubes.getShaderForRenderer(r.getRendererType()),
    ) catch unreachable);

    var custom_mesh = Renderer.obj.zmesh.Shape.initCube();
    defer custom_mesh.deinit();
    custom_mesh.computeNormals();
    const custom_static_mesh = Renderer.obj.shapeToStaticMesh(allocator, custom_mesh);
    const custom_mesh_handle = r.static_meshes.add(custom_static_mesh) catch unreachable;

    var transform = math.identity();

    while (!window.shouldClose()) {
        while (window.pollEvent()) |event| {
            switch (event) {
                .quit => break,
                .window_resized => |size| {
                    main_view.onResize(@intCast(size[0]), @intCast(size[1]));
                    bgfx.reset(@intCast(size[0]), @intCast(size[1]), bgfx.ResetFlags_None, .RGBA8);
                },
                else => {},
            }
        }

        // spin cube!
        transform = math.mul(transform, math.rotationX(0.001));
        // main_view.model = math.matToArr(transform);
        main_view.apply();

        // r.drawToView(
        //     &main_view,
        //     cube_mesh,
        //     cube_shader,
        //     &math.identityArr(),
        //     .default_2d,
        // )
        r.drawToView(&main_view, custom_mesh_handle, cube_shader, &math.matToArr(transform), .default_3d);

        r.frame();
    }
}
