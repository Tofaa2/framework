const runtime = @import("runtime");
const std = @import("std");

pub fn setupBinds(binds: *runtime.Keybinds) void {
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

pub fn setupCameraSystem(application: *runtime.App) void {
    const camera = findCamera(application).?;
    application.renderer.getView(.@"3d").?.view_mtx = camera.getViewMatrix();
    application.renderer.getView(.@"3d").?.proj_mtx = camera.getProjectionMatrix(application.renderer.viewport.width, application.renderer.viewport.height);

    application.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const app: *runtime.App = @ptrCast(@alignCast(world.ctx.?));

            const cam = findCamera(app) orelse return;
            app.renderer.getView(.@"3d").?.view_mtx = cam.getViewMatrix();
            app.renderer.getView(.@"3d").?.proj_mtx = cam.getProjectionMatrix(app.renderer.viewport.width, app.renderer.viewport.height);
        }
    }.f)
        .reads(runtime.Camera3D)
        .writes(runtime.Transform)
        .append();

    application.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const app: *runtime.App = @ptrCast(@alignCast(world.ctx.?));
            const cam = findCamera(app) orelse return;
            const delta = app.window.getMouseDelta();
            if (delta[0] != 0 or delta[1] != 0) {
                cam.rotate(delta[0], delta[1]);
            }
        }
    }.f)
        .writes(runtime.Camera3D)
        .append();
}

fn findCamera(app: *runtime.App) ?*runtime.Camera3D {
    var view = app.world.basicView(runtime.Camera3D);
    var it = view.mutIterator();
    if (it.next()) |camera| {
        return camera;
    }
    return null;
}

pub fn setFPSMax(application: *runtime.App, limit: ?u32) void {
    application.time.fps_limit = limit;
}

pub fn drawText(app: *runtime.App, font: *runtime.Font, content: []const u8, anchor: runtime.Anchor) void {
    const entity = app.world.create();
    app.world.add(entity, runtime.Transform{});
    app.world.add(entity, runtime.Renderable{ .text = .{ .font = font, .content = content } });
    app.world.add(entity, anchor);
}
pub fn drawFPS(app: *runtime.App, font: *runtime.Font, anchor: runtime.Anchor) void {
    const fps_label = app.world.create();
    var fps_buf: [64]u8 = undefined;
    app.world.add(fps_label, runtime.Transform{});
    app.world.add(fps_label, runtime.Renderable{
        .fmt_text = .{
            .font = font,
            .buf = &fps_buf,
            .format_fn = struct {
                fn f(buf: []u8, a: *runtime.App) []u8 {
                    const fps = a.resources.get(runtime.primitive.FpsCounter).?.fps;
                    return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
                }
            }.f,
        },
    });

    app.world.add(fps_label, anchor);
    app.world.add(fps_label, runtime.Color.red);
}
