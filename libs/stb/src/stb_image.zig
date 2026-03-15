pub const c = @cImport({
    @cInclude("stb_image.h");
});

const std = @import("std");

pub const Image = struct {
    data: [*c]u8,
    width: u32,
    height: u32,
    channels: u8,

    pub fn deinit(self: *Image) void {
        c.stbi_image_free(self.data);
    }

    pub fn init(path: []const u8, err_message: *?[]const u8) !Image {
        var width: u32 = undefined;
        var height: u32 = undefined;
        var channels: u8 = undefined;
        const data = c.stbi_load(
            @ptrCast(path.ptr),
            &width,
            &height,
            &channels,
            c.STBI_rgb_alpha,
        );
        if (data == null) {
            err_message.* = std.mem.span(c.stbi_failure_reason());
            return error.StbiLoadFailed;
        }

        return .{
            .data = data,
            .width = width,
            .height = height,
            .channels = channels,
        };
    }
};
