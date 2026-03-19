const math = @import("../renderer/math.zig");
const zm = math;
const Camera2D = @This();

x: f32 = 0,
y: f32 = 0,
zoom: f32 = 1.0,

pub fn getViewMatrix(self: Camera2D) zm.Mat {
    const t = zm.translation(-self.x, -self.y, 0.0);
    const s = zm.scaling(self.zoom, self.zoom, 1.0);
    return zm.mul(s, t);
}

pub fn move(self: *Camera2D, dx: f32, dy: f32) void {
    self.x += dx;
    self.y += dy;
}

pub fn zoomBy(self: *Camera2D, delta: f32) void {
    self.zoom += delta;
    self.zoom = @max(0.1, self.zoom);
}
