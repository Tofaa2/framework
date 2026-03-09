const c = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", "1");
    @cInclude("stb_image.h");
});
const bgfx = @import("bgfx.zig");

pub const Image = struct {
    handle: bgfx.TextureHandle,
    width: u32,
    height: u32,

    pub fn deinit(self: *const Image) void {
        bgfx.destroyTexture(self.handle);
    }

    pub fn initSingleColor(
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    ) Image {
        const boba: [4]u8 = .{
            r, g, b, a
        };
        return initOwned(&boba, 1, 1);
    }

    /// Initialize with bgfx owning the data.
    pub fn initOwned(data: ?*const anyopaque, width: u32, height: u32) Image{
        const handle = bgfx.createTexture2D(
            @intCast(width),
            @intCast(height),
            false, 1,
            .RGBA8,
                     bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
            bgfx.copy(data, @intCast(width * height * 4)),
            0
            );
        return .{
            .handle = handle,
            .width = width,
            .height = height,
        };
    }



    /// Initialize with the caller owning the data.
    pub fn initRef(data: ?*const anyopaque, width: u32, height: u32) Image{
        const handle = bgfx.createTexture2D(
            @intCast(width),
            @intCast(height),
            false, 1,
            .RGBA8,
                     bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
            bgfx.makeRef(data, @intCast(width * height * 4)),
            0
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

        const data = c.stbi_load(@ptrCast(path.ptr), &width, &height, null, c.STBI_rgb_alpha);
        defer c.stbi_image_free(data);
        const handle = bgfx.createTexture2D(
            @intCast(width),
            @intCast(height),
            false, 1,
            .RGBA8,
                     bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
            bgfx.copy(&data, @intCast(width * height * 4)),
            0
            );
        return .{
            .handle = handle,
            .width = width,
            .height = height,
        };
    }
};

pub const Image0 = struct {
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
