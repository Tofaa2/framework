const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator(); // std.heap.c_allocator;

    var app = try runtime.App.init(allocator, .{
        .name = "Hello, World",
        .width = 800,
        .height = 600,
    });
    defer app.deinit();

    const font = try app.assets.loadAsset(runtime.Font, runtime.Font.initFile("assets/Roboto-Regular.ttf", 32, 512));

    app.window.setMouseCaptured(true);
    app.time.fps_limit = 165;

    const player = app.world.create();
    app.world.add(player, runtime.Camera3D.init());

    setupBinds(app.keybinds);
    setupCameraSystem(app);

    var fps_buf: [64]u8 = undefined;
    createFpsLabel(app, font, fps_buf[0..]);
    createSun(app);
    createCircle(app);
    try createBunny(app);
    app.run();

    try app.scheduler.addStage(.{
        .name = "spin_bunny",
        .phase = .update,
        .run = struct {
            fn func(appl: *runtime.App) void {
                var iter = appl.world.basicView(Bunny).entityIterator();
                while (iter.next()) |bunny_entity| {
                    var transform = appl.world.get(runtime.Transform, bunny_entity);
                    transform.rotation = .{
                        transform.rotation[0] + 0.01,
                        transform.rotation[1] + 0.01,
                        transform.rotation[2] + 0.01,
                    };
                }
            }
        }.func,
    });
}

fn createSun(app: *runtime.App) void {
    const sun = app.world.create();
    app.world.add(sun, runtime.Transform{
        .rotation = .{ 0.5, -0.8, 0.3 },
    });
    app.world.add(sun, runtime.Light{
        .color = .white,
        .intensity = 1.0,
    });
}

fn setupBinds(binds: *runtime.Keybinds) void {
    binds.bind(.{ .key = .w, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveForward(dt);
        }
    }.f });

    binds.bind(.{ .key = .s, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveBackward(dt);
        }
    }.f });

    binds.bind(.{ .key = .a, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveLeft(dt);
        }
    }.f });

    binds.bind(.{ .key = .d, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveRight(dt);
        }
    }.f });
    binds.bind(.{ .key = .escape, .on_press = struct {
        fn f(app: *runtime.App) void {
            app.window.setMouseCaptured(false);
        }
    }.f });
    binds.bind(.{ .key = .space, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveUp(dt);
        }
    }.f });

    binds.bind(.{ .key = .shiftL, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            findCamera(app).?.moveDown(dt);
        }
    }.f });
}

fn setupCameraSystem(application: *runtime.App) void {
    application.scheduler.addStage(.{
        .name = "camera_3d",
        .phase = .update,
        .priority = 80,
        .run = struct {
            fn f(app: *runtime.App) void {
                app.renderer.getView(.@"3d").?.view_mtx = findCamera(app).?.getViewMatrix();
            }
        }.f,
    }) catch unreachable;
    application.scheduler.addStage(.{
        .name = "mouse_look",
        .phase = .update,
        .priority = 90,
        .run = struct {
            fn f(app: *runtime.App) void {
                const cam = findCamera(app) orelse return;
                const delta = app.window.getMouseDelta();
                if (delta[0] != 0 or delta[1] != 0) {
                    cam.rotate(delta[0], delta[1]);
                }
            }
        }.f,
    }) catch unreachable;
}

fn findCamera(app: *runtime.App) ?*runtime.Camera3D {
    var view = app.world.basicView(runtime.Camera3D);
    var it = view.mutIterator();
    if (it.next()) |camera| {
        return camera;
    }
    return null;
}

fn createFpsLabel(app: *runtime.App, font: runtime.Handle(runtime.Font), fps_buf: []u8) void {
    const fps_label = app.world.create();
    app.world.add(fps_label, runtime.Transform{});
    app.world.add(fps_label, runtime.Anchor{ .point = .top_center });
    app.world.add(fps_label, runtime.Renderable{ .fmt_text = .{
        .font = font,
        .buf = fps_buf,
        .format_fn = struct {
            fn f(buf: []u8, appl: *runtime.App) []u8 {
                const fps = appl.time.fps.fps;
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
            }
        }.f,
    } });
}

pub const Bunny = struct {};

fn createCircle(app: *runtime.App) void {
    const circle = app.world.create();
    app.world.add(circle, runtime.Transform{
        .center = .{ 100.0, 100.0, 0.0 },
    });
    app.world.add(circle, runtime.Renderable{ .circle = .{ .radius = 50, .segments = 64 } });
}

fn createBunny(app: *runtime.App) !void {
    const bunny_mesh = try app.assets.loadMesh("assets/animal-bunny.obj", &app.renderer.vertex_layout);
    const mesh_entity = app.world.create();
    app.world.add(mesh_entity, Bunny{});
    app.world.add(mesh_entity, runtime.Transform{
        .center = .{ 0.0, 0.0, 0.0 },
        .size = .{ 1.0, 1.0, 1.0 },
        .rotation = .{ 0.5, 0.0, 0.0 },
    });
    app.world.add(mesh_entity, runtime.Renderable{ .mesh = .{ .mesh = bunny_mesh } });
}

// pub fn main() !void {
//     const bunny_mesh = try application.assets.loadMesh(application.allocators.generic, "assets/animal-bunny.obj", &application.renderer.vertex_layout);
//     const mesh_entity = application.world.create();
//     application.world.add(mesh_entity, runtime.primitive.Transform{
//         .center = .{ 0.0, 0.0, 0.0 },
//         .size = .{ 1.0, 1.0, 1.0 },
//         .rotation = .{ 0.5, 0.0, 0.0 },
//     });
//     application.world.add(mesh_entity, runtime.primitive.Renderable{ .mesh = .{ .mesh = bunny_mesh} });
// }
