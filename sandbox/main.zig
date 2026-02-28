const std = @import("std");
const framework = @import("framework");
const window = @import("window");
const renderer = @import("renderer");

pub fn main() !void {
    var w = try window.Window.init(std.heap.page_allocator, "Hello, Mogus", 800, 600);
    defer w.deinit();
    var r = try renderer.Renderer.init(.{
        .native_handle = w.getNativeHandle(),
        .allocator = std.heap.page_allocator,
        .width = 800,
        .height = 600,
        // .vsync = false,
    });
    defer {
        std.log.info("about to deinit", .{});
        r.deinit();
    }

    // _ = try r.addPass(.{ .bloom = .{ .threshold = 0.8, .intensity = 1.2 } });

    var spin: f32 = 0.0;
    var cam = renderer.Camera.firstPerson(.init(0.0, 0.0, -5.0));
    while (!w.shouldClose()) {
        w.update();
        const input = w.getInput();
        const dt: f32 = 0.0016; // or track real delta time
        // Movement
        if (input.isKeyPressed(.W)) cam.moveForward(5.0 * dt);
        if (input.isKeyPressed(.S)) cam.moveForward(-5.0 * dt);
        if (input.isKeyPressed(.A)) cam.moveRight(-5.0 * dt);
        if (input.isKeyPressed(.D)) cam.moveRight(5.0 * dt);
        if (input.isKeyPressed(.Space)) cam.moveUp(5.0 * dt);
        if (input.isKeyPressed(.LeftShift)) cam.moveUp(-5.0 * dt);

        // Mouse look
        const mouse = input.getMouseDelta();
        cam.addYaw(@as(f32, @floatFromInt(mouse.x)) * 0.002);
        cam.addPitch(@as(f32, @floatFromInt(-mouse.y)) * 0.002);

        r.beginFrame();

        r.setCamera(cam.viewMatrix());
        spin += 1.0 * dt;

        r.drawRect(100, 100, 50, 50, 0xFFFFFFFF);
        r.drawBox(
            .init(
                .init(0.0, 0.0, 0.0),
                .init(0.0, spin, 0.0),
                .init(1.0, 1.0, 1.0),
            ),
            .init(1, 1, 1),
            0xFF0000FF,
        );

        r.endFrame();

        if (w.getInput().isKeyJustPressed(.Escape)) {
            break;
        }
    }
}

fn runApp() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = framework.App.init(
        .{
            .name = "test",
            .allocators = .{
                .frame = allocator,
                .generic = allocator,
                .world = allocator,
            },
        },
    );
    defer app.deinit();

    app.run();
}
