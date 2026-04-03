const std = @import("std");
const orin = @import("orin");
const rgfw = @import("rgfw");
const renderer = @import("renderer");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var window = try allocator.create(rgfw.Window);
    defer allocator.destroy(window);
    try window.init("Hello, World", 800, 600);

    var r = try allocator.create(renderer.Renderer);
    defer allocator.destroy(r);
    try r.init(.{
        .allocator = allocator,
        .ndt = window.getNativePtr(),
        .nwh = window.getNativeNdt(),
        .width = @intCast(window.getSize()[0]),
        .height = @intCast(window.getSize()[1]),
    });
    defer r.deinit();

    const monitor = rgfw.Monitor.getPrimary();
    const mode = monitor.getMode();

    std.debug.print("{s} Refresh rate: {d}", .{ monitor.getName(), mode.refresh_rate });

    while (!window.shouldClose()) {
        while (window.pollEvent()) |event| {
            if (event == .quit) {
                break;
            }
        }
        r.flush();
    }
}
