const bgfx = @import("bgfx").bgfx;
const Cubemap = @This();
const Image = @import("Image.zig");
const std =  @import("std");

handle: bgfx.TextureHandle,

pub const Faces = struct {
    right: []const u8,  // +X
    left: []const u8,   // -X
    top: []const u8,    // +Y
    bottom: []const u8, // -Y
    front: []const u8,  // +Z
    back: []const u8,   // -Z
};

pub fn initFromFiles(faces: Faces) !Cubemap {
    const right   = Image.initFile(faces.right);
    const left    = Image.initFile(faces.left);
    const top     = Image.initFile(faces.top);
    const bottom  = Image.initFile(faces.bottom);
    const front   = Image.initFile(faces.front);
    const back    = Image.initFile(faces.back);

    const size: u16 = @intCast(right.width);
    const handle = bgfx.createTextureCube(
        size,
        false,
        1,
        .RGBA8,
        bgfx.TextureFlags_None,
        null,
    );

    // update each face
    const faces_data = [6]*const Image{ &right, &left, &top, &bottom, &front, &back };
    for (faces_data, 0..) |face, i| {
        _ = bgfx.updateTextureCube(
            handle,
            0,
            @intCast(i),
            0, 0,
            size, size,
            bgfx.copy(face.data.ptr, @intCast(face.data.len)),
            std.math.maxInt(u16),
        );
    }

    return Cubemap{ .handle = handle };
}

pub fn deinit(self: *Cubemap) void {
    bgfx.destroyTexture(self.handle);
}
