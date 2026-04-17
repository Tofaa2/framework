/// GPU texture handle + metadata wrapper.
/// Supports loading from a file path (via stb_image) or from raw RGBA bytes.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const stb = @import("stb");
const Texture = @This();

handle: bgfx.TextureHandle,
width: u32,
height: u32,
format: bgfx.TextureFormat,

pub const Error = error{
    LoadFailed,
    UploadFailed,
};

/// Load a texture from a file path. Supports PNG, JPG, BMP, TGA, etc.
/// The path must be null-terminated (sentinel `[:0]const u8`).
pub fn initFromFile(path: [:0]const u8) Error!Texture {
    var err_buf: [256]u8 = undefined;
    const img = stb.image.Image.init(path, .rgba, &err_buf) catch {
        std.log.err("[renderer] Failed to load texture '{s}'", .{path});
        return Error.LoadFailed;
    };
    defer img.deinit();
    return initFromRgba(img.data[0 .. img.width * img.height * 4], img.width, img.height);
}

/// Load a texture from encoded image data (PNG, JPG, etc.) in memory.
pub fn initFromMemory(pixels: []const u8) Error!Texture {
    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;
    const data = stb.image.c.stbi_load_from_memory(
        @ptrCast(pixels.ptr),
        @intCast(pixels.len),
        &width,
        &height,
        &channels,
        @intCast(stb.image.c.STBI_rgb_alpha),
    );
    if (data == null) {
        std.log.err("[renderer] Failed to decode embedded texture", .{});
        return Error.LoadFailed;
    }
    defer stb.image.c.stbi_image_free(data);
    const rgba_data = data[0..@as(usize, @intCast(width * height * 4))];
    return initFromRgba(rgba_data, @intCast(width), @intCast(height));
}

/// Load a texture from pre-decoded RGBA8 pixel data.
pub fn initFromRgba(pixels: []const u8, width: u32, height: u32) Error!Texture {
    const mem = bgfx.copy(@ptrCast(pixels.ptr), @intCast(pixels.len));
    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.TextureFlags_None,
        mem,
        0,
    );
    if (handle.idx == std.math.maxInt(u16)) return Error.UploadFailed;
    return .{
        .handle = handle,
        .width = width,
        .height = height,
        .format = .RGBA8,
    };
}

/// Create an empty render-target texture (for framebuffer attachments).
pub fn initRenderTarget(
    width: u32,
    height: u32,
    format: bgfx.TextureFormat,
    flags: u64,
) Error!Texture {
    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        format,
        @intCast(bgfx.TextureFlags_Rt | flags),
        null,
        0,
    );
    if (handle.idx == std.math.maxInt(u16)) return Error.UploadFailed;
    return .{
        .handle = handle,
        .width = width,
        .height = height,
        .format = format,
    };
}

pub fn deinit(self: *Texture) void {
    bgfx.destroyTexture(self.handle);
}
