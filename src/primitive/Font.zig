const std = @import("std");
const c = @import("../core/c.zig").stb;
const Image = @import("Image.zig");

const Font = @This();

pub const Glyph = struct {
    // UV coordinates in the atlas texture
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    // glyph metrics
    width: f32,
    height: f32,
    x_offset: f32,
    y_offset: f32,
    x_advance: f32,
};

atlas: Image,
glyphs: [96]Glyph,
font_size: f32,
atlas_size: u32,
baseline_offset: f32,

ascent: f32,

pub fn initFile(path: []const u8, font_size: f32, atlas_size: u32) Font {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.panic("Failed to open font file: {s} — {}\n", .{ path, err });
    };
    defer file.close();

    const file_size = file.getEndPos() catch unreachable;
    const buf = std.heap.c_allocator.alloc(u8, file_size) catch unreachable;
    defer std.heap.c_allocator.free(buf);

    _ = file.readAll(buf) catch unreachable;
    return init(buf, font_size, atlas_size);
}

pub fn init(ttf_data: []const u8, font_size: f32, atlas_size: u32) Font {
    const bitmap = std.heap.c_allocator.alloc(u8, atlas_size * atlas_size) catch unreachable;
    defer std.heap.c_allocator.free(bitmap);

    var char_data: [96]c.stbtt_bakedchar = undefined;

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

    const rgba = std.heap.c_allocator.alloc(u8, atlas_size * atlas_size * 4) catch unreachable;
    defer std.heap.c_allocator.free(rgba);
    for (0..atlas_size * atlas_size) |i| {
        rgba[i * 4 + 0] = bitmap[i]; // B
        rgba[i * 4 + 1] = bitmap[i]; // G
        rgba[i * 4 + 2] = bitmap[i]; // R
        rgba[i * 4 + 3] = bitmap[i]; // A
    }
    c.stbi_set_flip_vertically_on_load(0);
    const atlas = Image.initFontAtlas(rgba.ptr, atlas_size, atlas_size);
    c.stbi_set_flip_vertically_on_load(1);
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
    const ref = char_data['H' - 32];
    const baseline_offset = ref.yoff;

    var min_y_offset: f32 = 0;
    for (glyphs) |g| {
        if (g.y_offset < min_y_offset) min_y_offset = g.y_offset;
    }

    return .{
        .atlas = atlas,
        .glyphs = glyphs,
        .font_size = font_size,
        .atlas_size = atlas_size,
        .baseline_offset = baseline_offset,
        .ascent = -min_y_offset,
    };
}

pub fn getGlyph(self: *const Font, char: u8) ?*const Glyph {
    if (char < 32 or char > 127) return null;
    return &self.glyphs[char - 32];
}

pub fn deinit(self: *Font) void {
    self.atlas.deinit();
}
