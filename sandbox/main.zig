const std = @import("std");
const framework = @import("framework");

const window = @import("window");

pub fn main() !void {
    var w = try window.Window().init(std.heap.page_allocator, "Hello, Mogus", 800, 600);
    defer w.deinit();
    while (!w.shouldClose()) {
        w.update();
    }
    // window.windows.wWinMain();
    // std.debug.print("Hello, world!\n", .{});
    // try runApp();
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
