const std = @import("std");

pub const prelude = @import("prelude.zig");

// Exported namespaces
pub const App = @import("App.zig");
pub const PluginManager = prelude.plugin.PluginManager(App);
pub const Time = @import("Time.zig");

pub const window = @import("window");
pub const Window = window.Window;

pub const stb = @import("stb");
pub const math = @import("math");
pub const bgfx = @import("bgfx");
pub const renderer = @import("renderer/root.zig");

pub fn runCooler(allocator: std.mem.Allocator) !void {
    var app = App.init(.{
        .name = "framework",
        .allocators = .{
            .frame = allocator,
            .generic = allocator,
            .world = allocator,
        },
    });
    defer app.deinit();

    try app.scheduler.addStage(
        .{
            .name = "test",
            .phase = .update,
            .run = struct {
                fn func(a: *App) void {
                    const time = a.resources.get(Time).?;
                    std.debug.print("Time Delta: {any}\n", .{time.delta});
                }
            }.func,
        },
    );
    app.run();
}

// Exported modules
/// TODO: Actually make this nice after finishing the renderer.
pub fn run(allocator: std.mem.Allocator) !void {
    var w = window.Window.init("Hello, World", 800, 600);
    defer w.deinit();

    var r = try renderer.Renderer.init(allocator, .{ .height = 600, .width = 800 }, w.getNativePtr(), true);
    defer r.deinit();

    while (!w.shouldClose()) {
        w.update();

        r.draw();
        if (w.isKeyReleased(.@"3")) {
            break;
        }
    }
}
