/// Represents an RGBA8 color component.
/// Provides helper constants and conversions for different color formats.
const Color = @This();

/// Red component (0-255).
r: u8,
/// Green component (0-255).
g: u8,
/// Blue component (0-255).
b: u8,
/// Alpha component (0-255).
a: u8,

/// Color constants for standard colors.
pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
pub const green = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
pub const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };
pub const yellow = Color{ .r = 255, .g = 255, .b = 0, .a = 255 };
pub const magenta = Color{ .r = 255, .g = 0, .b = 255, .a = 255 };
pub const cyan = Color{ .r = 0, .g = 255, .b = 255, .a = 255 };

pub fn merge(self: Color, other: Color) Color {
    return Color{
        .r = @as(u8, @truncate(@as(u16, self.r) + @as(u16, other.r))),
        .g = @as(u8, @truncate(@as(u16, self.g) + @as(u16, other.g))),
        .b = @as(u8, @truncate(@as(u16, self.b) + @as(u16, other.b))),
        .a = @as(u8, @truncate(@as(u16, self.a) + @as(u16, other.a))),
    };
}

pub fn toABGR(self: Color) u32 {
    return @as(u32, self.a) << 24 | @as(u32, self.b) << 16 | @as(u32, self.g) << 8 | @as(u32, self.r);
}

pub fn toRGBA(self: Color) u32 {
    return @as(u32, self.r) << 24 | @as(u32, self.g) << 16 | @as(u32, self.b) << 8 | @as(u32, self.a);
}

pub fn fromRGBA(rgba: u32) Color {
    return Color{
        .r = @as(u8, @truncate(rgba >> 16)),
        .g = @as(u8, @truncate(rgba >> 8)),
        .b = @as(u8, @truncate(rgba)),
        .a = @as(u8, @truncate(rgba >> 24)),
    };
}

pub fn fromHex(hex: u32) Color {
    return Color{
        .r = @as(u8, @truncate(hex >> 16)),
        .g = @as(u8, @truncate(hex >> 8)),
        .b = @as(u8, @truncate(hex)),
        .a = @as(u8, @truncate(hex >> 24)),
    };
}

pub fn fromABGR(abgr: u32) Color {
    return Color{
        .r = @as(u8, @truncate(abgr)),
        .g = @as(u8, @truncate(abgr >> 8)),
        .b = @as(u8, @truncate(abgr >> 16)),
        .a = @as(u8, @truncate(abgr >> 24)),
    };
}
