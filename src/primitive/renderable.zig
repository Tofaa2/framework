const Image = @import("Image.zig");
const Font = @import("Font.zig");

pub const Renderable = union(enum) {
    circle: struct {
        radius: f32,
        segments: ?u32 = null,
    },
    rect: struct {
        width: f32,
        height: f32,
    },
    sprite: struct {
        image: *const Image,
        uv: ?struct { u0: f32, v0: f32, u1: f32, v1: f32 } = null,
    },
    text: struct {
        font: *const Font,
        content: []const u8,
    },
};
