/// 2D sprite & shape batch renderer using bgfx transient vertex/index buffers.
/// All geometry is re-uploaded every frame — zero persistent GPU allocations.
/// Batches consecutive draws with the same texture into a single bgfx submit.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");
const Texture = @import("Texture.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const DrawEncoder = @import("DrawEncoder.zig");
const UniformStore = @import("UniformStore.zig");
const Batch2D = @This();

/// Vertex layout for 2D sprites: position(xy), texcoord(uv), color(rgba8).
pub const SpriteVertex = struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    /// ABGR packed colour (bgfx convention).
    abgr: u32,
};

/// Maximum quads per batch. Adjust based on expected 2D scene complexity.
pub const MAX_QUADS: u32 = 8192;
pub const MAX_VERTS: u32 = MAX_QUADS * 4;
pub const MAX_INDICES: u32 = MAX_QUADS * 6;

vertices: []SpriteVertex,
indices: []u16,
vertex_count: u32,
index_count: u32,
current_texture: ?bgfx.TextureHandle,
program: ShaderProgram,
layout: bgfx.VertexLayout,
allocator: std.mem.Allocator,

pub fn init(
    allocator: std.mem.Allocator,
    program: ShaderProgram,
) !Batch2D {
    const verts = try allocator.alloc(SpriteVertex, MAX_VERTS);
    errdefer allocator.free(verts);
    const idxs = try allocator.alloc(u16, MAX_INDICES);
    errdefer allocator.free(idxs);

    // Build vertex layout matching SpriteVertex
    var layout: bgfx.VertexLayout = undefined;
    _ = layout.begin(bgfx.getRendererType());
    _ = layout.add(.Position, 2, .Float, false, false);
    _ = layout.add(.TexCoord0, 2, .Float, false, false);
    _ = layout.add(.Color0, 4, .Uint8, true, false);
    layout.end();

    return .{
        .vertices = verts,
        .indices = idxs,
        .vertex_count = 0,
        .index_count = 0,
        .current_texture = null,
        .program = program,
        .layout = layout,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Batch2D) void {
    self.allocator.free(self.vertices);
    self.allocator.free(self.indices);
    self.program.deinit();
}

/// Begin a new frame — reset counts.
pub fn begin(self: *Batch2D) void {
    self.vertex_count = 0;
    self.index_count = 0;
    self.current_texture = null;
}

/// Push a textured quad. Flushes first if texture changes or buffer full.
pub fn pushQuad(
    self: *Batch2D,
    view_id: u16,
    u: *UniformStore,
    dest: math.Rect,
    uv: math.Rect,
    color: math.Vec4,
    texture: ?bgfx.TextureHandle,
) void {
    const tex_changed = if (texture != null and self.current_texture != null)
        texture.?.idx != self.current_texture.?.idx
    else
        (texture == null) != (self.current_texture == null);

    if (self.vertex_count + 4 > MAX_VERTS or
        self.index_count + 6 > MAX_INDICES or
        tex_changed)
    {
        self.flush(view_id, u);
    }

    self.current_texture = texture;

    const abgr = packColor(color);
    const base_v = self.vertex_count;

    // Four corners: TL, TR, BR, BL
    self.vertices[base_v + 0] = .{ .x = dest.x, .y = dest.y, .u = uv.x, .v = uv.y, .abgr = abgr };
    self.vertices[base_v + 1] = .{ .x = dest.x + dest.width, .y = dest.y, .u = uv.x + uv.width, .v = uv.y, .abgr = abgr };
    self.vertices[base_v + 2] = .{ .x = dest.x + dest.width, .y = dest.y + dest.height, .u = uv.x + uv.width, .v = uv.y + uv.height, .abgr = abgr };
    self.vertices[base_v + 3] = .{ .x = dest.x, .y = dest.y + dest.height, .u = uv.x, .v = uv.y + uv.height, .abgr = abgr };

    const base_i = self.index_count;
    const bv: u16 = @intCast(base_v);
    self.indices[base_i + 0] = bv + 0;
    self.indices[base_i + 1] = bv + 1;
    self.indices[base_i + 2] = bv + 2;
    self.indices[base_i + 3] = bv + 0;
    self.indices[base_i + 4] = bv + 2;
    self.indices[base_i + 5] = bv + 3;

    self.vertex_count += 4;
    self.index_count += 6;
}

/// Push a solid-color rectangle (no texture).
pub fn pushRect(self: *Batch2D, view_id: u16, u: *UniformStore, rect: math.Rect, color: math.Vec4) void {
    const uv = math.Rect{ .x = 0, .y = 0, .width = 1, .height = 1 };
    self.pushQuad(view_id, u, rect, uv, color, null);
}

/// Flush accumulated geometry to the GPU and issue the draw call.
pub fn flush(self: *Batch2D, view_id: u16, u: *UniformStore) void {
    if (self.vertex_count == 0) return;

    const enc = DrawEncoder.init(view_id);

    // Allocate transient buffers
    var tvb: bgfx.TransientVertexBuffer = undefined;
    var tib: bgfx.TransientIndexBuffer = undefined;

    if (bgfx.getAvailTransientVertexBuffer(self.vertex_count, &self.layout) < self.vertex_count) {
        std.log.warn("[Batch2D] transient vertex buffer full — skipping flush", .{});
        self.vertex_count = 0;
        self.index_count = 0;
        return;
    }
    if (bgfx.getAvailTransientIndexBuffer(self.index_count, false) < self.index_count) {
        std.log.warn("[Batch2D] transient index buffer full — skipping flush", .{});
        self.vertex_count = 0;
        self.index_count = 0;
        return;
    }

    bgfx.allocTransientVertexBuffer(&tvb, self.vertex_count, &self.layout);
    bgfx.allocTransientIndexBuffer(&tib, self.index_count, false);

    // Copy CPU data into transient buffers
    const vb_dst = @as([*]SpriteVertex, @ptrCast(@alignCast(tvb.data)))[0..self.vertex_count];
    @memcpy(vb_dst, self.vertices[0..self.vertex_count]);
    const ib_dst = @as([*]u16, @ptrCast(@alignCast(tib.data)))[0..self.index_count];
    @memcpy(ib_dst, self.indices[0..self.index_count]);

    // Bind texture or signal no-texture
    if (self.current_texture) |tex| {
        const h_sampler = u.sampler("s_texColor");
        enc.setTexture(0, h_sampler, tex, std.math.maxInt(u32));
        const yes: math.Vec4 = .{ .x = 1, .y = 0, .z = 0, .w = 0 };
        enc.setVec4(u.vec4("u_useTexture"), &yes);
    } else {
        const no: math.Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
        enc.setVec4(u.vec4("u_useTexture"), &no);
    }

    enc.setTransientVertexBuffer(&tvb, 0, self.vertex_count);
    enc.setTransientIndexBuffer(&tib, 0, self.index_count);
    enc.setStateFlags(DrawEncoder.STATE_2D);
    enc.submit(self.program, 0);

    self.vertex_count = 0;
    self.index_count = 0;
    self.current_texture = null;
}

// ---- Helpers ----------------------------------------------------------------

fn packColor(c: math.Vec4) u32 {
    const r: u32 = @intFromFloat(@min(c.x * 255, 255));
    const g: u32 = @intFromFloat(@min(c.y * 255, 255));
    const b: u32 = @intFromFloat(@min(c.z * 255, 255));
    const a: u32 = @intFromFloat(@min(c.w * 255, 255));
    // bgfx ABGR format
    return (a << 24) | (b << 16) | (g << 8) | r;
}
