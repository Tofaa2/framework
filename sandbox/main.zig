const std = @import("std");
const framework = @import("framework-runtime");

pub const std_options = std.Options{
    .logFn = framework.utils.logFn,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var window = try framework.window.Window.init(allocator, "Hello, Mogus", 800, 600);
    defer window.deinit();

    var renderer = try framework.renderer.Renderer.init(window.getNativeHandle(), 800, 600);
    defer renderer.deinit();

    while (!window.shouldClose()) {
        window.update();
        renderer.beginFrame(null);
        renderer.drawLine2D(100, 200, 200, 300, 5, 0xFF000000);
        renderer.drawCircle2D(100, 100, 50, 128, 0xFFFF00FF);
        renderer.endFrame();
    }
}
