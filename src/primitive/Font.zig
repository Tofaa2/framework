const std = @import("std");
const c = @import("../core/c.zig").stb;
const Image = @import("Image.zig");

const Font = @This();

pub const Glyph = struct {
    // UV coordinates in the atlas texture
    u0: f32,
    v0: f32, // top-left
    u1: f32,
    v1: f32, // bottom-right
    // glyph metrics
    width: f32,
    height: f32,
    x_offset: f32, // offset from cursor to glyph left
    y_offset: f32, // offset from cursor to glyph top
    x_advance: f32, // how far to move cursor after this glyph
};

atlas: Image,
glyphs: [96]Glyph, // ASCII 32-127 (space to ~)
font_size: f32,
atlas_size: u32,

pub fn initFile(path: []const u8, font_size: f32, atlas_size: u32) Font {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.panic("Failed to open font file: {s} — {}\n", .{ path, err });
    };
    defer file.close();

    const file_size = file.getEndPos() catch unreachable;
    const buf = std.heap.c_allocator.alloc(u8, file_size) catch unreachable;
    defer std.heap.c_allocator.free(buf);

    _ = file.readAll(buf) catch unreachable;
    return Font.init(buf, font_size, atlas_size);
}

pub fn init(ttf_data: []const u8, font_size: f32, atlas_size: u32) Font {
    // allocate bitmap for the atlas
    const bitmap = std.heap.c_allocator.alloc(u8, atlas_size * atlas_size) catch unreachable;
    defer std.heap.c_allocator.free(bitmap);

    var char_data: [96]c.stbtt_bakedchar = undefined;

    // bake ASCII 32-127 into the bitmap
    _ = c.stbtt_BakeFontBitmap(
        ttf_data.ptr,
        0, // font offset in file
        font_size,
        bitmap.ptr,
        @intCast(atlas_size),
        @intCast(atlas_size),
        32, // first char
        96, // num chars
        &char_data,
    );

    // convert single channel bitmap to RGBA for bgfx
    const rgba = std.heap.c_allocator.alloc(u8, atlas_size * atlas_size * 4) catch unreachable;
    defer std.heap.c_allocator.free(rgba);
    for (0..atlas_size * atlas_size) |i| {
        rgba[i * 4 + 0] = bitmap[i]; // B
        rgba[i * 4 + 1] = bitmap[i]; // G
        rgba[i * 4 + 2] = bitmap[i]; // R
        rgba[i * 4 + 3] = bitmap[i]; // A
    }
    // for (0..atlas_size * atlas_size) |i| {
    //     rgba[i * 4 + 0] = 255; // R
    //     rgba[i * 4 + 1] = 255; // G
    //     rgba[i * 4 + 2] = 255; // B
    //     rgba[i * 4 + 3] = bitmap[i]; // A — the actual glyph coverage
    // }
    c.stbi_set_flip_vertically_on_load(0); // disable flip for font atlas
    // const atlas = Image.initOwned(rgba.ptr, atlas_size, atlas_size);
    const atlas = Image.initFontAtlas(rgba.ptr, atlas_size, atlas_size);
    c.stbi_set_flip_vertically_on_load(1); // re-enable for regular images
    // convert stbtt_bakedchar to our Glyph format
    var glyphs: [96]Glyph = undefined;
    const atlas_f: f32 = @floatFromInt(atlas_size);
    for (0..96) |i| {
        const bc = char_data[i];
        glyphs[i] = .{
            .u0 = @as(f32, @floatFromInt(bc.x0)) / atlas_f,
            .v0 = @as(f32, @floatFromInt(bc.y0)) / atlas_f,
            .u1 = @as(f32, @floatFromInt(bc.x1)) / atlas_f,
            .v1 = @as(f32, @floatFromInt(bc.y1)) / atlas_f,
            .width = @floatFromInt(bc.x1 - bc.x0),
            .height = @floatFromInt(bc.y1 - bc.y0),
            .x_offset = bc.xoff,
            .y_offset = bc.yoff,
            .x_advance = bc.xadvance,
        };
    }
    _ = c.stbi_write_png(
        "atlas_debug.png",
        @intCast(atlas_size),
        @intCast(atlas_size),
        1, // single channel
        bitmap.ptr,
        @intCast(atlas_size),
    );
    std.debug.print("rgba[0..16]: ", .{});
    for (0..16) |i| {
        std.debug.print("{d} ", .{rgba[i]});
    }
    std.debug.print("\n", .{});

    return .{
        .atlas = atlas,
        .glyphs = glyphs,
        .font_size = font_size,
        .atlas_size = atlas_size,
    };
}

pub fn getGlyph(self: *const Font, char: u8) ?*const Glyph {
    if (char < 32 or char > 127) return null;
    return &self.glyphs[char - 32];
}

pub fn deinit(self: *Font) void {
    self.atlas.deinit();
}
