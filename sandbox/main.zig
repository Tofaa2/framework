const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var application = runtime.App.init(.{
        .name = "sandbox",
        .allocators = .{
            .frame = arena_allocator,
            .generic = allocator,
            .world = allocator,
            .frame_arena = arena,
        },
    });
    defer application.deinit();

    // const shinoa = try application.assets.loadImage("assets/shinoa.png");

    const font = try application.assets.loadFont("assets/Roboto-Regular.ttf", 32, 512);
    // var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    // defer font.deinit();
    const camera_3d = runtime.primitive.Camera3D.init();
    application.resources.add(camera_3d) catch unreachable;

    application.scheduler.addStage(.{
        .name = "camera_3d",
        .phase = .update,
        .priority = 80,
        .run = struct {
            fn f(app: *runtime.App) void {
                const cam = app.resources.getMut(runtime.primitive.Camera3D) orelse return;
                app.renderer.getView(.@"3d").?.view_mtx = cam.getViewMatrix();
            }
        }.f,
    }) catch unreachable;
    var binds = runtime.primitive.Keybinds.init(allocator);
    binds.bind(.{ .key = .w, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveForward(dt);
        }
    }.f });

    binds.bind(.{ .key = .s, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveBackward(dt);
        }
    }.f });

    binds.bind(.{ .key = .a, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.time.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveLeft(dt);
        }
    }.f });

    binds.bind(.{ .key = .d, .on_held = struct {
        fn f(app: *runtime.App) void {

            const dt: f32 = @floatCast(app.time.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveRight(dt);
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
            app.resources.getMut(runtime.primitive.Camera3D).?.moveUp(dt);
        }
    }.f });

    binds.bind(.{ .key = .shiftL, .on_held = struct {
        fn f(app: *runtime.App) void {
            
            const dt: f32 = @floatCast(app.time.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveDown(dt);
        }
    }.f });
    application.window.setMouseCaptured(true);
    application.resources.add(binds) catch unreachable;
    application.scheduler.addStage(.{
        .name = "keybinds",
        .phase = .update,
        .priority = 90,
        .run = struct {
            fn f(app: *runtime.App) void {
                app.resources.getMut(runtime.primitive.Keybinds).?.update(app);
            }
        }.f,
    }) catch unreachable;
    application.scheduler.addStage(.{
        .name = "mouse_look",
        .phase = .update,
        .priority = 90,
        .run = struct {
            fn f(app: *runtime.App) void {
                const cam = app.resources.getMut(runtime.primitive.Camera3D) orelse return;
                var win = app.window;
                const delta = win.getMouseDelta();
                if (delta[0] != 0 or delta[1] != 0) {
                    cam.rotate(delta[0], delta[1]);
                }
            }
        }.f,
    }) catch unreachable;
    const circle = application.world.create();
    application.world.add(circle, runtime.primitive.Transform{
        .center = .{ 100.0, 100.0, 0.0 },
    });
    application.world.add(circle, runtime.primitive.Renderable{ .circle = .{ .radius = 50, .segments = 64 } });

    const fps_label = application.world.create();
    var fps_buf: [64]u8 = undefined;
    application.world.add(fps_label, runtime.primitive.Transform{
        .center = .{
            540.0,
            10.0,
            0.0,
        },
    });
    application.world.add(fps_label, runtime.primitive.Renderable{ .fmt_text = .{
        .font = font,
        .buf = &fps_buf,
        .format_fn = struct {
            fn f(buf: []u8, app: *runtime.App) []u8 {
                const fps = app.time.fps.fps;
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
            }
        }.f,            
    } });

    application.time.fps_limit = 165;
    var renderer = application.renderer;
    var obj_builder = runtime.renderer.MeshBuilder.init(allocator);
    defer obj_builder.deinit();
    const result = try runtime.renderer.ObjLoader.load(allocator, "assets/animal-bunny.obj", &obj_builder);
    var obj_mesh = obj_builder.buildMesh(&renderer.vertex_layout);
    obj_mesh.owned_texture = result.texture; // add this line
    const mesh_entity = application.world.create();
    application.world.add(mesh_entity, runtime.primitive.Transform{
        .center = .{ 0.0, 0.0, 0.0 },
        .size = .{ 1.0, 1.0, 1.0 },
        .rotation = .{ 0.5, 0.0, 0.0 },
    });
    application.world.add(mesh_entity, runtime.primitive.Renderable{ .mesh = .{ .mesh = &obj_mesh } });

    const sun = application.world.create();
    application.world.add(sun, runtime.primitive.Transform{
        .rotation = .{ 0.5, -0.8, 0.3 },
    });
    application.world.add(sun, runtime.primitive.Light{
        .color = .white,
        .intensity = 12.0, // was 1.0
    });

    application.run();
}

fn updateCamera2d(app: *runtime.App) void {
    const cam = app.resources.getMut(runtime.primitive.Camera2D) orelse return;
    app.renderer.getView(.@"2d").?.view_mtx = cam.getViewMatrix();
}
