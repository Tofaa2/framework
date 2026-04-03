const std = @import("std");
const orin = @import("orin");
const rgfw = @import("rgfw");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var window = try rgfw.Window.init("Hello, World", 800, 600);
    defer window.deinit();

    const monitor = rgfw.Monitor.getPrimary();
    const mode = monitor.getMode();

    std.debug.print("{s} Refresh rate: {d}", .{ monitor.getName(), mode.refresh_rate });

    while (!window.shouldClose()) {
        while (window.pollEvent()) |event| {
            if (event == .quit) {
                break;
            }
        }
    }
}
