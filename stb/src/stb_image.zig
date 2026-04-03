const std = @import("std");
pub const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});

pub fn setFlipVerticallyOnLoad(value: bool) void {
    c.stbi_set_flip_vertically_on_load(value);
}

pub fn setFlipVerticallyOnWrite(value: bool) void {
    c.stbi_flip_vertically_on_write(@intFromBool(value));
}
pub const ImageError = error{
    FailedToLoad,
    FailedToFormat,
};

pub const DesiredChannels = enum(c_int) {
    rgb = c.STBI_rgb,
    rgba = c.STBI_rgb_alpha,
    gray = c.STBI_grey,
    gray_alpha = c.STBI_grey_alpha,
    default = c.STBI_default,
};

pub const Image = struct {
    width: u32,
    height: u32,
    channels: u32,
    data: [*c]u8,

    pub fn init(path: [:0]const u8, desired_channel: DesiredChannels, err_buf: ?[]u8) ImageError!Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var channels: c_int = undefined;
        const data = c.stbi_load(@ptrCast(path.ptr), &width, &height, &channels, @intFromEnum(desired_channel));
        if (data == null) {
            const reason = c.stbi_failure_reason();
            if (err_buf) |buf| {
                _ = std.fmt.bufPrintZ(buf, "{s}", .{reason}) catch return ImageError.FailedToFormat;
            }
            return ImageError.FailedToLoad;
        }
        return .{
            .width = @intCast(width),
            .height = @intCast(height),
            .channels = @intCast(channels),
            .data = data,
        };
    }

    pub fn deinit(self: *const Image) void {
        c.stbi_image_free(self.data);
    }
};
