const bgfx = @import("bgfx").bgfx;
const c = @import("../utils/stb_image.zig").c;
const Color = @import("../components/Color.zig");
const std = @import("std");

const Image = @This();
handle: bgfx.TextureHandle,
width: u32,
height: u32,

pub fn deinit(self: *const Image) void {
    bgfx.destroyTexture(self.handle);
}

pub fn initSingleColor(
    color: Color,
) Image {
    const boba: [4]u8 = .{ color.r, color.g, color.b, color.a };
    return initOwned(&boba, 1, 1);
}

/// Initialize with bgfx owning the data.
pub fn initOwned(data: ?*const anyopaque, width: u32, height: u32) Image {
    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
        bgfx.copy(data, @intCast(width * height * 4)),
        0,
    );
    return .{
        .handle = handle,
        .width = width,
        .height = height,
    };
}

/// Initialize with the caller owning the data.
pub fn initRef(data: ?*const anyopaque, width: u32, height: u32) Image {
    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
        bgfx.makeRef(data, @intCast(width * height * 4)),
        0,
    );
    return .{
        .handle = handle,
        .width = width,
        .height = height,
    };
}
pub fn initFontAtlas(data: ?*const anyopaque, width: u32, height: u32) Image {
    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.SamplerFlags_UClamp | bgfx.SamplerFlags_VClamp,
        bgfx.copy(data, @intCast(width * height * 4)),
        0,
    );
    return .{
        .handle = handle,
        .width = width,
        .height = height,
    };
}
/// Initialize from file, BGFX owns the data.
pub fn initFile(
    path: []const u8,
) Image {
    var width: u32 = 0;
    var height: u32 = 0;
    c.stbi_set_flip_vertically_on_load(1);
    const data = c.stbi_load(@ptrCast(path.ptr), @ptrCast(&width), @ptrCast(&height), null, c.STBI_rgb_alpha);

    defer c.stbi_image_free(data);

    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
        bgfx.copy(@ptrCast(data), @intCast(width * height * 4)),
        0,
    );
    return .{
        .handle = handle,
        .width = width,
        .height = height,
    };
}
