const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try runtime.App.init(allocator, .{
        .name = "Physics Demo",
        .width = 1280,
        .height = 720,
    });
    defer app.deinit();

    app.time.fps_limit = 165;
    app.window.setMouseCaptured(true);

    const player = app.world.create();
    app.world.add(player, runtime.Camera3D.init());
    var cam = app.world.get(runtime.Camera3D, player);
    cam.position = .{ 0, 5, 15, 1 };
    cam.pitch = -0.3;
    setupCamera(app);

    const sun = app.world.create();
    app.world.add(sun, runtime.Transform{ .rotation = .{ 0.6, -0.8, 0.2 } });
    app.world.add(sun, runtime.Light{ .color = .white, .intensity = 1.2 });

    const bunny_mesh = try app.assets.loadMesh("assets/animal-bunny.obj", &app.renderer.vertex_layout);

    var builder = runtime.MeshBuilder.init(allocator);
    builder.pushCube(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, runtime.Color.white);
    const floor_mesh_raw = builder.buildMesh(&app.renderer.vertex_layout);
    const floor_mesh_handle = try app.assets.loadAsset(runtime.Mesh, floor_mesh_raw);
    builder.deinit();

    const floor = app.world.create();
    app.world.add(floor, runtime.Transform{
        .center = .{ 0.0, -2.0, 0.0 },
        .size = .{ 20.0, 0.5, 20.0 },
    });
    app.world.add(floor, runtime.Renderable{ .mesh = .{ .mesh = floor_mesh_handle } });
    app.world.add(floor, runtime.RigidBody{ .is_static = true });
    // Use a large AABB for the floor
    app.world.add(floor, runtime.Collider{ .half_extents = .{ 10.0, 0.25, 10.0 } });

    std.log.info("Starting Physics Demo...", .{});

    // --- Falling Bunnies ------------------------------------------------
    const count = 5;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const x = @as(f32, @floatFromInt(i)) * 2.0 - 4.0;
        const y = 5.0 + @as(f32, @floatFromInt(i)) * 2.0;

        const bunny = app.world.create();
        app.world.add(bunny, runtime.Transform{
            .center = .{ x, y, 0.0 },
            .size = .{ 1.0, 1.0, 1.0 },
        });
        app.world.add(bunny, runtime.Renderable{ .mesh = .{ .mesh = bunny_mesh } });
        app.world.add(bunny, runtime.RigidBody{
            .mass = 1.0,
            .restitution = 0.5,
        });
        app.world.add(bunny, runtime.Gravity{});
        app.world.add(bunny, runtime.Collider{ .half_extents = .{ 0.5, 0.5, 0.5 } });
    }

    // --- FPS label -----------------------------------------------------
    const font = try app.assets.loadAsset(runtime.Font, runtime.Font.initFile("assets/Roboto-Regular.ttf", 24, 512));
    var fps_buf: [64]u8 = undefined;
    const fps_label = app.world.create();
    app.world.add(fps_label, runtime.Transform{});
    app.world.add(fps_label, runtime.Anchor{ .point = .top_left, .offset = .{ 10, 10 } });
    app.world.add(fps_label, runtime.Renderable{ .fmt_text = .{
        .font = font,
        .buf = fps_buf[0..],
        .format_fn = struct {
            fn f(buf: []u8, appl: *runtime.App) []u8 {
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{appl.time.fps.fps}) catch buf[0..0];
            }
        }.f,
    } });

    app.run();
}

fn findCam(app: *runtime.App) ?*runtime.Camera3D {
    var view = app.world.basicView(runtime.Camera3D);
    var it = view.mutIterator();
    return it.next();
}

fn setupCamera(app: *runtime.App) void {
    app.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const appl: *runtime.App = @ptrCast(@alignCast(world.ctx.?));
            if (findCam(appl)) |cam| {
                appl.renderer.getView(.@"3d").?.view_mtx = cam.getViewMatrix();
            }
        }
    }.f)
        .reads(runtime.Camera3D)
        .append();

    app.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const appl: *runtime.App = @ptrCast(@alignCast(world.ctx.?));
            const cam = findCam(appl) orelse return;
            const delta = appl.window.getMouseDelta();
            if (delta[0] != 0 or delta[1] != 0) cam.rotate(delta[0], delta[1]);
        }
    }.f)
        .writes(runtime.Camera3D)
        .append();

    app.keybinds.bind(.{ .key = .w, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveForward(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .s, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveBackward(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .a, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveLeft(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .d, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveRight(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .space, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveUp(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .shiftL, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveDown(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .escape, .on_press = struct {
        fn f(appl: *runtime.App) void {
            appl.window.setMouseCaptured(false);
        }
    }.f });
}
