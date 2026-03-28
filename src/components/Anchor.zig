/// Defines a reference point for positioning UI elements relative to a viewport.
const Anchor = @This();

/// The anchor point on the screen.
point: Point = .top_left,
/// Pixels to offset from the anchor point.
offset: [2]f32 = .{ 0.0, 0.0 }, // offset from anchor point in pixels

pub const Point = enum {
    top_left,
    top_center,
    top_right,
    center_left,
    center,
    center_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub fn resolve(self: *const Anchor, viewport_w: f32, viewport_h: f32) [2]f32 {
    const base = switch (self.point) {
        .top_left => .{ 0, 0 },
        .top_center => .{ viewport_w / 2, 0 },
        .top_right => .{ viewport_w, 0 },
        .center_left => .{ 0, viewport_h / 2 },
        .center => .{ viewport_w / 2, viewport_h / 2 },
        .center_right => .{ viewport_w, viewport_h / 2 },
        .bottom_left => .{ 0, viewport_h },
        .bottom_center => .{ viewport_w / 2, viewport_h },
        .bottom_right => .{ viewport_w, viewport_h },
    };
    return .{ base[0] + self.offset[0], base[1] + self.offset[1] };
}
