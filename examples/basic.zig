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

    const circle = app.world.create();
    app.world.add(circle, runtime.Transform{});
    app.world.add(circle, runtime.Anchor{ .point = .center });
    app.world.add(circle, runtime.Renderable{
        .circle = .{ .radius = 100, .segments = 128 },
    });
    app.run();
}
