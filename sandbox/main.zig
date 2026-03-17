const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = runtime.App.init(.{ .name = "sandbox", .allocators = .{ .frame = allocator, .generic = allocator, .world = allocator } });
    defer app.deinit();
    try app.scheduler.addStage(
        .{
            .name = "test",
            .phase = .update,
            .run = struct {
                fn func(a: *runtime.App) void {
                    const time = a.resources.get(runtime.Time).?;
                    std.debug.print("Time Delta: {any}\n", .{time.delta});
                }
            }.func,
        },
    );
    // try app.plugins.add(Window.Plugin{}, .{ .title = "Sandbox", .width = 800, .height = 600 });
    // try app.plugins.add(Renderer.Plugin{}, .{});
    app.run();

    std.debug.print("Hello, World!\n", .{});
}
