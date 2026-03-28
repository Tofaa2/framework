/// Defines a component for spatial transformation in both 2D and 3D scenes.
/// Manages entity position, scale, and rotation.
const Self = @This();
const math = @import("../renderer/math.zig");
const zm = math;

/// World-space position of the entity center.
center: [3]f32 = .{ 0.0, 0.0, 0.0 },
/// World-space scale of the entity across X, Y, and Z axes.
size: [3]f32 = .{ 1.0, 1.0, 1.0 },
/// Euler rotation angles in radians for X, Y, and Z axes.
rotation: [3]f32 = .{ 0.0, 0.0, 0.0 }, // euler X, Y, Z in radians
pub fn toMatrix(self: *const Self) zm.Mat {
    const s = zm.scaling(self.size[0], self.size[1], self.size[2]);
    const rx = zm.rotationX(self.rotation[0]);
    const ry = zm.rotationY(self.rotation[1]);
    const rz = zm.rotationZ(self.rotation[2]);
    const r = zm.mul(zm.mul(rx, ry), rz);
    const t = zm.translation(self.center[0], self.center[1], self.center[2]);
    return zm.mul(t, zm.mul(r, s));
}

pub fn toMatrix0(self: *const Self) zm.Mat {
    const s = zm.scaling(self.size[0], self.size[1], self.size[2]);
    const rx = zm.rotationX(self.rotation[0]);
    const ry = zm.rotationY(self.rotation[1]);
    const rz = zm.rotationZ(self.rotation[2]);
    const r = zm.mul(zm.mul(rx, ry), rz);
    const t = zm.translation(self.center[0], self.center[1], self.center[2]);
    return zm.mul(zm.mul(s, r), t);
}
