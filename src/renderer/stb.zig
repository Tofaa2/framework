const c = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", "1");
    @cInclude("stb_image.h");
});
const bgfx = @import("bgfx.zig");

pub const Image = struct {
    width: u32,
    height: u32,
    data: [*c]u8,

    pub fn toBgfx(self: *Image) bgfx.TextureHandle {
        return bgfx.createTexture2D(
            @intCast(self.width),
            @intCast(self.height),
            false,
            1,
            .RGBA8,
            bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
            bgfx.copy(&self.data, @intCast(self.width * self.height * 4)),
            @intCast(@intFromPtr(&self.data)),
        );
    }

    pub fn toBgfxAndDeinit(self: *Image) bgfx.TextureHandle {
        const a = self.toBgfx();
        c.stbi_image_free(self.data);
        return a;
    }

    pub fn init(path: []const u8, width: u32, height: u32) Image {
        var structure = Image{
            .width = width,
            .height = height,
            .data = undefined,
        };
        structure.data = c.stbi_load(@ptrCast(path.ptr), &structure.width, &structure.height, null, c.STBI_rgb_alpha);
        return structure;
    }

    pub fn deinit(self: *Image) void {
        c.stbi_image_free(self.data);
    }
};
