const bgfx = @import("bgfx.zig");
const std = @import("std");
const stb = @import("../root.zig").c.stb;

pub const Font = struct {
    cdata: [96]stb.stbtt_bakedchar,
    texture: bgfx.TextureHandle,
    size: f32,
    atlas_size: i32 = 512,
    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8, size: f32) !Font {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const ttf_data = try file.readToEndAlloc(allocator, 1024 * 1024 * 8); // 8MB max
        defer allocator.free(ttf_data);

        return Font.init(allocator, ttf_data, size);
    }
    pub fn init(allocator: std.mem.Allocator, ttf_data: []const u8, size: f32) !Font {
        const atlas_size = 512;

        const temp_bitmap = try allocator.alloc(u8, atlas_size * atlas_size);
        defer allocator.free(temp_bitmap);

        var cdata: [96]stb.stbtt_bakedchar = undefined;
        _ = stb.stbtt_BakeFontBitmap(ttf_data.ptr, 0, size, temp_bitmap.ptr, atlas_size, atlas_size, 32, 96, &cdata);

        // Convert the 8-bit alpha map into 32-bit RGBA for the basic shader
        const rgba_bitmap = try allocator.alloc(u32, atlas_size * atlas_size);
        defer allocator.free(rgba_bitmap);

        for (temp_bitmap, 0..) |alpha, i| {
            // White pixel with font alpha: A B G R
            rgba_bitmap[i] = (@as(u32, alpha) << 24) | 0x00FFFFFF;
        }

        const mem = bgfx.copy(rgba_bitmap.ptr, @intCast(rgba_bitmap.len * @sizeOf(u32)));
        const tex = bgfx.createTexture2D(
            @intCast(atlas_size),
            @intCast(atlas_size),
            false,
            1,
            .RGBA8,
            bgfx.SamplerFlags_UClamp | bgfx.SamplerFlags_VClamp | bgfx.SamplerFlags_MinPoint | bgfx.SamplerFlags_MagPoint,
            mem,
            0,
        );

        return Font{
            .cdata = cdata,
            .texture = tex,
            .size = size,
            .atlas_size = atlas_size,
        };
    }

    pub fn deinit(self: *Font) void {
        bgfx.destroyTexture(self.texture);
    }
};
