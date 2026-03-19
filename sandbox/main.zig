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

    const shinoa = runtime.primitive.Image.initFile("assets/shinoa.png");
    defer shinoa.deinit();

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();

    const camera = runtime.primitive.Camera2D{};
    application.resources.add(camera) catch unreachable;

    var binds = runtime.primitive.Keybinds.init(allocator);
    binds.bind(.{
        .key = .w,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.move(0, @floatCast(-300.0 * dt));
            }
        }.f,
    });
    binds.bind(.{
        .key = .s,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.move(0, @floatCast(300.0 * dt));
            }
        }.f,
    });
    binds.bind(.{
        .key = .a,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.move(@floatCast(-300.0 * dt), 0);
            }
        }.f,
    });
    binds.bind(.{
        .key = .d,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.move(@floatCast(300.0 * dt), 0);
            }
        }.f,
    });
    binds.bind(.{
        .key = .q,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.zoomBy(@floatCast(-1.0 * dt));
            }
        }.f,
    });
    binds.bind(.{
        .key = .e,
        .on_held = struct {
            fn f(app: *runtime.App) void {
                const dt = app.resources.get(runtime.primitive.Time).?.delta;
                app.resources.getMut(runtime.primitive.Camera2D).?.zoomBy(@floatCast(1.0 * dt));
            }
        }.f,
    });
    application.resources.add(binds) catch unreachable;
    application.scheduler.addStage(.{ .name = "keybinds", .phase = .update, .run = struct {
        fn f(app: *runtime.App) void {
            app.resources.getMut(runtime.primitive.Keybinds).?.update(app);
        }
    }.f }) catch unreachable;

    application.scheduler.addStage(.{ .name = "camera", .phase = .update, .run = updateCamera }) catch unreachable;

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

    application.run();
}
fn updateCamera(app: *runtime.App) void {
    const cam = app.resources.getMut(runtime.primitive.Camera2D) orelse return;
    const renderer = app.resources.getMut(runtime.renderer.Renderer) orelse return;
    renderer.getView(.@"2d").?.view_mtx = cam.getViewMatrix();
}
