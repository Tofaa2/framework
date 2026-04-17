/// bgfx framebuffer wrapper.
/// Manages a set of color and optional depth texture attachments.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const Texture = @import("Texture.zig");
const Framebuffer = @This();

pub const Attachment = union(enum) {
    /// RGBA color target.
    color: struct {
        format: bgfx.TextureFormat = .RGBA8,
        /// Extra bgfx texture flags (e.g. filtering). RT flag is always added.
        extra_flags: u64 = 0,
    },
    /// Depth (or depth-stencil) target.
    depth: struct {
        format: bgfx.TextureFormat = .D24S8,
    },
};

pub const Config = struct {
    attachments: []const Attachment,
    width: u32,
    height: u32,
};

handle: bgfx.FrameBufferHandle,
textures: []Texture,
width: u32,
height: u32,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, config: Config) !Framebuffer {
    const textures = try allocator.alloc(Texture, config.attachments.len);
    errdefer allocator.free(textures);

    for (config.attachments, 0..) |att, i| {
        textures[i] = switch (att) {
            .color => |c| try Texture.initRenderTarget(config.width, config.height, c.format, c.extra_flags),
            .depth => |d| try Texture.initRenderTarget(config.width, config.height, d.format, 0),
        };
    }

    var handles: [8]bgfx.TextureHandle = undefined;
    for (textures, 0..) |t, i| handles[i] = t.handle;

    const fb = bgfx.createFrameBufferFromHandles(@intCast(textures.len), &handles, false);
    return .{
        .handle = fb,
        .textures = textures,
        .width = config.width,
        .height = config.height,
        .allocator = allocator,
    };
}

/// Destroy and recreate with new dimensions.
pub fn resize(self: *Framebuffer, config: Config) !void {
    self.deinit();
    self.* = try Framebuffer.init(self.allocator, config);
}

pub fn deinit(self: *Framebuffer) void {
    bgfx.destroyFrameBuffer(self.handle);
    for (self.textures) |*t| t.deinit();
    self.allocator.free(self.textures);
}

/// Convenience: get the first color attachment texture handle.
pub fn colorTexture(self: *const Framebuffer) bgfx.TextureHandle {
    return self.textures[0].handle;
}

pub fn depthTexture(self: *const Framebuffer) bgfx.TextureHandle {
    for (self.textures) |tex| {
        if (tex.format == .D24S8 or tex.format == .D32 or tex.format == .D16) {
            return tex.handle;
        }
    }
    return self.textures[0].handle;
}
