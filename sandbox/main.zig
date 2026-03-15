const std = @import("std");
const fw = @import("window");
const bgfx = @import("bgfx");
const fw_runtime = @import("framework-runtime");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try fw_runtime.run(allocator);
}
