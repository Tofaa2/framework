const Self = @This();
const bgfx = @import("bgfx").bgfx;
const std = @import("std");

handle: bgfx.FrameBufferHandle,
color_attachment: bgfx.TextureHandle,
depth_stencil_attachment: bgfx.TextureHandle,

pub fn init(width: u32, height: u32) Self {
    const color = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA8,
        bgfx.TextureFlags_Rt,
        null,
        0,
    );
    const depth_stencil = bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .D24S8,
        bgfx.TextureFlags_Rt,
        null,
        0,
    );

    const attachments: [2]bgfx.Attachment = std.mem.zeroes([2]bgfx.Attachment);
    attachments[0].init(color);
    attachments[1].init(depth_stencil);

    const handle = bgfx.createFrameBufferFromAttachment(2, &attachments, true);

    return Self{
        .handle = handle,
        .color_attachment = color,
        .depth_stencil_attachment = depth_stencil,
    };
}

pub fn deinit(self: *Self) void {
    bgfx.destroyFrameBuffer(self.handle);
}
