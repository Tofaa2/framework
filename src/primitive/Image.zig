const bgfx = @import("bgfx").bgfx;
const c = @import("../core/c.zig").stb;
const Color = @import("Color.zig");
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
    // _ = data;
    // // temp: make a checkerboard to verify texture upload works
    // const test_size = width * height * 4;
    // const test_data = std.heap.c_allocator.alloc(u8, test_size) catch unreachable;
    // defer std.heap.c_allocator.free(test_data);
    // for (0..width * height) |i| {
    //     const checker = if ((i % 2) == 0) @as(u8, 255) else @as(u8, 0);
    //     test_data[i * 4 + 0] = checker; // R
    //     test_data[i * 4 + 1] = 0; // G
    //     test_data[i * 4 + 2] = checker; // B
    //     test_data[i * 4 + 3] = 255; // A
    // }
    // const handle = bgfx.createTexture2D(
    //     @intCast(width),
    //     @intCast(height),
    //     false,
    //     1,
    //     .RGBA8,
    //     bgfx.SamplerFlags_UClamp | bgfx.SamplerFlags_VClamp,
    //     bgfx.copy(test_data.ptr, @intCast(test_size)),
    //     0,
    // );
    // return .{ .handle = handle, .width = width, .height = height };
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
    std.debug.print("width: {d}, height: {d}, data: {*}\n", .{ width, height, data });
    if (data == null) {
        std.debug.panic("Failed to load image: {s}\n", .{path});
    }

    defer c.stbi_image_free(data);

    const handle = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.SamplerFlags_Point | bgfx.SamplerFlags_UvwClamp,
        bgfx.copy(@ptrCast(data), @intCast(width * height * 4)),
        // bgfx.copy(data, @intCast(width * height * 4)),
        0,
    );
    return .{
        .handle = handle,
        .width = width,
        .height = height,
    };
}
