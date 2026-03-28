/// Axis-aligned bounding box (AABB) collider for 2D and 3D physics.
/// The AABB world position = entity Transform.center + offset.
pub const Collider = @This();

/// Half-extents in world units: (half-width X, half-height Y, half-depth Z).
/// For 2D physics set Z to 0 or a large value to ignore depth.
half_extents: [3]f32,
/// Local offset from the entity's Transform.center.
offset: [3]f32 = .{ 0.0, 0.0, 0.0 },
/// If true, collision is detected but not physically resolved.
is_trigger: bool = false,

pub fn worldCenter(self: Collider, center: [3]f32) [3]f32 {
    return .{
        center[0] + self.offset[0],
        center[1] + self.offset[1],
        center[2] + self.offset[2],
    };
}
