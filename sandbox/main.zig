const std = @import("std");
const bgfx = @import("bgfx");
const fw = @import("framework-runtime");
const Window = @import("window");
const Renderer = @import("renderer");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = fw.App.init(.{ .name = "sandbox", .allocators = .{ .frame = allocator, .generic = allocator, .world = allocator } });
    defer app.deinit();
    // try app.scheduler.addStage(
    //     .{
    //         .name = "test",
    //         .phase = .update,
    //         .run = struct {
    //             fn func(a: *fw.App) void {
    //                 const time = a.resources.get(fw.Time).?;
    //                 std.debug.print("Time Delta: {any}\n", .{time.delta});
    //             }
    //         }.func,
    //     },
    // );
    try app.plugins.add(Window.Plugin{}, .{ .title = "Sandbox", .width = 800, .height = 600 });
    try app.plugins.add(Renderer.Plugin{}, .{});
    app.run();
}
