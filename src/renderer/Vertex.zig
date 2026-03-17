const math = @import("math");
const Self = @This();
const Color = @import("Color.zig");
position: [3]f32,
color: u32,
tex_coords: [2]f32,

pub fn init(position: [3]f32, color: Color, tex_coords: ?[2]f32) Self {
    return .{
        .position = position,
        .color = color.toABGR(),
        .tex_coords = tex_coords orelse .{ 0.0, 0.0 },
    };
}
