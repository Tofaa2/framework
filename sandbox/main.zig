const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();

    var renderer = application.resources.getMut(runtime.renderer.Renderer).?;

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
        .font = &font,
        .buf = &fps_buf,
        .format_fn = struct {
            fn f(buf: []u8, app: *runtime.App) []u8 {
                const fps = app.resources.get(runtime.primitive.FpsCounter).?.fps;
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
            }
        }.f,
    } });

    try application.resources.add(runtime.ui.UIContext.init(allocator, &font, renderer.getView(.ui).?));
    try application.scheduler.addStage(.{
        .name = "draw-ui",
        .priority = 90,
        .phase = .render,
        .run = drawUi,
    });

    application.run();
}

fn drawUi(app: *runtime.App) void {
    var ui = app.resources.getMut(runtime.ui.UIContext).?;
    const window = app.resources.getMut(runtime.platform.Window).?;
    const renderer = app.resources.getMut(runtime.renderer.Renderer).?;

    // refresh view pointer each frame
    ui.view = renderer.getView(.@"2d").?;

    ui.begin(window);
    ui.rect(0, 0, 200, 600, .{ .r = 30, .g = 30, .b = 30, .a = 220 });
    if (ui.button("Save", 8, 8, 184, 32)) {
        std.debug.print("Save clicked!\n", .{});
    }
    if (ui.button("Load", 8, 48, 184, 32)) {
        std.debug.print("Load clicked!\n", .{});
    }
    ui.label("Hello World", 8, 100, .white);
    ui.end();
}

pub fn main0() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
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

    const shinoa = runtime.primitive.Image.initFile("assets/shinoa.png");
    defer shinoa.deinit();

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();
    const camera_3d = runtime.primitive.Camera3D.init();
    application.resources.add(camera_3d) catch unreachable;

    application.scheduler.addStage(.{
        .name = "camera_3d",
        .phase = .update,
        .priority = 80,
        .run = struct {
            fn f(app: *runtime.App) void {
                const cam = app.resources.getMut(runtime.primitive.Camera3D) orelse return;
                const renderer = app.resources.getMut(runtime.renderer.Renderer) orelse return;
                renderer.getView(.@"3d").?.view_mtx = cam.getViewMatrix();
            }
        }.f,
    }) catch unreachable;
    var binds = runtime.primitive.Keybinds.init(allocator);
    binds.bind(.{ .key = .w, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveForward(dt);
        }
    }.f });

    binds.bind(.{ .key = .s, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveBackward(dt);
        }
    }.f });

    binds.bind(.{ .key = .a, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveLeft(dt);
        }
    }.f });

    binds.bind(.{ .key = .d, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveRight(dt);
        }
    }.f });
    binds.bind(.{ .key = .escape, .on_press = struct {
        fn f(app: *runtime.App) void {
            app.resources.getMut(runtime.platform.Window).?.setMouseCaptured(false);
        }
    }.f });
    binds.bind(.{ .key = .space, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveUp(dt);
        }
    }.f });

    binds.bind(.{ .key = .shiftL, .on_held = struct {
        fn f(app: *runtime.App) void {
            const dt: f32 = @floatCast(app.resources.get(runtime.primitive.Time).?.delta);
            app.resources.getMut(runtime.primitive.Camera3D).?.moveDown(dt);
        }
    }.f });
    application.resources.getMut(runtime.platform.Window).?.setMouseCaptured(true);
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
                var win = app.resources.getMut(runtime.platform.Window).?;
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
        .font = &font,
        .buf = &fps_buf,
        .format_fn = struct {
            fn f(buf: []u8, app: *runtime.App) []u8 {
                const fps = app.resources.get(runtime.primitive.FpsCounter).?.fps;
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
            }
        }.f,
    } });

    application.resources.getMut(runtime.primitive.Time).?.fps_limit = 165;
    const renderer = application.resources.getMut(runtime.renderer.Renderer).?;

    var obj_builder = runtime.renderer.MeshBuilder.init(allocator);
    defer obj_builder.deinit();
    const result = try runtime.renderer.ObjLoader.load(allocator, "assets/animal-bunny.obj", &obj_builder);
    std.debug.print("texture loaded: {}\n", .{result.texture != null});
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
        .color = .red,
        .intensity = 12.0, // was 1.0
    });

    application.run();
}

fn updateCamera2d(app: *runtime.App) void {
    const cam = app.resources.getMut(runtime.primitive.Camera2D) orelse return;
    const renderer = app.resources.getMut(runtime.renderer.Renderer) orelse return;
    renderer.getView(.@"2d").?.view_mtx = cam.getViewMatrix();
}
