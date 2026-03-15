const std = @import("std");

// Exported namespaces

pub const window = @import("window");
pub const Window = window.Window;

pub const ResourcePool = @import("ResourcePool.zig");
pub const Scheduler = @import("scheduler.zig").Scheduler;
pub const App = @import("App.zig");

pub const plugin = @import("plugin.zig");
pub const PluginManager = plugin.PluginManager;

pub const stb = @import("stb");
pub const math = @import("math");
pub const bgfx = @import("bgfx");
pub const renderer = @import("renderer/root.zig");
pub const type_id = @import("type_id.zig");

pub fn runEnhanced(allocator: std.mem.Allocator) !void {
    var app = App.init(.{
        .name = "test-enhanced",
        .allocators = .{ .frame = allocator, .generic = allocator, .world = allocator },
    });
    defer app.deinit();
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
            std.debug.print("ESCAPE\n", .{});
            break;
        }
    }
}
