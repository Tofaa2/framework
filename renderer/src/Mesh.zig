/// GPU mesh — holds a static or dynamic vertex+index buffer pair.
/// Create with initStatic() for geometry that never changes,
/// or initDynamic() for CPU-writable per-frame geometry.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");
const vertex_parser = @import("vertex_parser.zig");
const Mesh = @This();

pub const Kind = enum { static, dynamic };

pub const StaticBuffers = struct {
    vb: bgfx.VertexBufferHandle,
    ib: bgfx.IndexBufferHandle,
};

pub const DynamicBuffers = struct {
    vb: bgfx.DynamicVertexBufferHandle,
    ib: bgfx.DynamicIndexBufferHandle,
};

pub const Buffers = union(Kind) {
    static: StaticBuffers,
    dynamic: DynamicBuffers,
};

buffers: Buffers,
layout: bgfx.VertexLayout,
vertex_count: u32,
index_count: u32,
aabb: math.AABB,

// ---- Static meshes ----------------------------------------------------------

/// Create a static (immutable) mesh from typed vertex data.
/// `V` is your vertex struct. Field names are auto-resolved via vertex_parser.
pub fn initStatic(
    comptime V: type,
    vertices: []const V,
    indices: []const u16,
    comptime info: vertex_parser.VertexInfo(V),
) !Mesh {
    const layout = vertex_parser.createLayout(V, info, bgfx.getRendererType());
    const vert_mem = bgfx.copy(@ptrCast(vertices.ptr), @intCast(@sizeOf(V) * vertices.len));
    const idx_mem = bgfx.copy(@ptrCast(indices.ptr), @intCast(@sizeOf(u16) * indices.len));

    const vb = bgfx.createVertexBuffer(vert_mem, &layout, bgfx.BufferFlags_None);
    const ib = bgfx.createIndexBuffer(idx_mem, bgfx.BufferFlags_None);
    if (vb.idx == std.math.maxInt(u16) or ib.idx == std.math.maxInt(u16))
        return error.BufferCreateFailed;

    return .{
        .buffers = .{ .static = .{ .vb = vb, .ib = ib } },
        .layout = layout,
        .vertex_count = @intCast(vertices.len),
        .index_count = @intCast(indices.len),
        .aabb = computeAabb(V, vertices),
    };
}

/// Create a static mesh from raw bytes (for loaders that produce raw data).
pub fn initStaticRaw(
    vertex_data: []const u8,
    index_data: []const u16,
    layout: bgfx.VertexLayout,
    vertex_count: u32,
    aabb: math.AABB,
) !Mesh {
    const vert_mem = bgfx.copy(@ptrCast(vertex_data.ptr), @intCast(vertex_data.len));
    const idx_mem = bgfx.copy(@ptrCast(index_data.ptr), @intCast(@sizeOf(u16) * index_data.len));

    const vb = bgfx.createVertexBuffer(vert_mem, &layout, bgfx.BufferFlags_None);
    const ib = bgfx.createIndexBuffer(idx_mem, bgfx.BufferFlags_None);
    if (vb.idx == std.math.maxInt(u16) or ib.idx == std.math.maxInt(u16))
        return error.BufferCreateFailed;

    return .{
        .buffers = .{ .static = .{ .vb = vb, .ib = ib } },
        .layout = layout,
        .vertex_count = vertex_count,
        .index_count = @intCast(index_data.len),
        .aabb = aabb,
    };
}

// ---- Dynamic meshes ---------------------------------------------------------

/// Create a dynamic mesh. CPU can update vertex/index data each frame.
pub fn initDynamic(
    comptime V: type,
    max_vertices: u32,
    max_indices: u32,
    comptime info: vertex_parser.VertexInfo(V),
) !Mesh {
    const layout = vertex_parser.createLayout(V, info, bgfx.getRendererType());
    const vb = bgfx.createDynamicVertexBuffer(max_vertices, &layout, bgfx.BufferFlags_None);
    const ib = bgfx.createDynamicIndexBuffer(max_indices, bgfx.BufferFlags_None);
    if (vb.idx == std.math.maxInt(u16) or ib.idx == std.math.maxInt(u16))
        return error.BufferCreateFailed;

    return .{
        .buffers = .{ .dynamic = .{ .vb = vb, .ib = ib } },
        .layout = layout,
        .vertex_count = max_vertices,
        .index_count = max_indices,
        .aabb = .{ .min = math.Vec3.zero(), .max = math.Vec3.zero() },
    };
}

/// Update the GPU buffers of a dynamic mesh.
pub fn updateDynamic(
    self: *Mesh,
    comptime V: type,
    vertices: []const V,
    indices: []const u16,
) void {
    std.debug.assert(self.buffers == .dynamic);
    const vb = self.buffers.dynamic.vb;
    const ib = self.buffers.dynamic.ib;
    const vert_mem = bgfx.copy(@ptrCast(vertices.ptr), @intCast(@sizeOf(V) * vertices.len));
    const idx_mem = bgfx.copy(@ptrCast(indices.ptr), @intCast(@sizeOf(u16) * indices.len));
    bgfx.updateDynamicVertexBuffer(vb, 0, vert_mem);
    bgfx.updateDynamicIndexBuffer(ib, 0, idx_mem);
    self.vertex_count = @intCast(vertices.len);
    self.index_count = @intCast(indices.len);
}

// ---- Lifecycle --------------------------------------------------------------

pub fn deinit(self: *Mesh) void {
    switch (self.buffers) {
        .static => |b| {
            bgfx.destroyVertexBuffer(b.vb);
            bgfx.destroyIndexBuffer(b.ib);
        },
        .dynamic => |b| {
            bgfx.destroyDynamicVertexBuffer(b.vb);
            bgfx.destroyDynamicIndexBuffer(b.ib);
        },
    }
}

// ---- Helpers ----------------------------------------------------------------

/// Compute AABB from an array of typed vertices. Requires a `position: Vec3` field.
fn computeAabb(comptime V: type, vertices: []const V) math.AABB {
    if (vertices.len == 0) return .{ .min = math.Vec3.zero(), .max = math.Vec3.zero() };
    const has_pos = comptime blk: {
        if (!@hasField(V, "position")) break :blk false;
        const f = std.meta.fields(V);
        for (f) |field| {
            if (std.mem.eql(u8, field.name, "position") and field.type == math.Vec3) break :blk true;
        }
        break :blk false;
    };
    if (!has_pos) return .{ .min = math.Vec3.zero(), .max = math.Vec3.zero() };

    var mn = vertices[0].position;
    var mx = vertices[0].position;
    for (vertices[1..]) |v| {
        mn = math.Vec3.new(@min(mn.x, v.position.x), @min(mn.y, v.position.y), @min(mn.z, v.position.z));
        mx = math.Vec3.new(@max(mx.x, v.position.x), @max(mx.y, v.position.y), @max(mx.z, v.position.z));
    }
    return .{ .min = mn, .max = mx };
}

// ---- Built-in primitive generators -----------------------------------------

/// Axis-aligned cube centred at origin with side length 2 (−1..1 on each axis).
/// Returns a Mesh using the provided vertex type (must have `position: Vec3`).
pub const Vertex = struct {
    position: math.Vec3,
    normal: math.Vec3,
    texcoord0: [2]f32,
};

pub const VertexWithColor = struct {
    position: math.Vec3,
    normal: math.Vec3,
    texcoord0: [2]f32,
    color0: math.Vec4,
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Mesh {
    const loader = @import("MeshLoader.zig");
    return loader.loadFromFile(allocator, path, .{});
}

pub fn createCube() !Mesh {
    const v = [_]Vertex{
        // front  (+Z)
        .{ .position = .{ .x = -1, .y = -1, .z = 1 }, .normal = .{ .x = 0, .y = 0, .z = 1 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = 1, .y = -1, .z = 1 }, .normal = .{ .x = 0, .y = 0, .z = 1 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = 1, .y = 1, .z = 1 }, .normal = .{ .x = 0, .y = 0, .z = 1 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = -1, .y = 1, .z = 1 }, .normal = .{ .x = 0, .y = 0, .z = 1 }, .texcoord0 = .{ 0, 0 } },
        // back   (−Z)
        .{ .position = .{ .x = 1, .y = -1, .z = -1 }, .normal = .{ .x = 0, .y = 0, .z = -1 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = -1, .y = -1, .z = -1 }, .normal = .{ .x = 0, .y = 0, .z = -1 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = -1, .y = 1, .z = -1 }, .normal = .{ .x = 0, .y = 0, .z = -1 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = 1, .y = 1, .z = -1 }, .normal = .{ .x = 0, .y = 0, .z = -1 }, .texcoord0 = .{ 0, 0 } },
        // left (−X)
        .{ .position = .{ .x = -1, .y = -1, .z = -1 }, .normal = .{ .x = -1, .y = 0, .z = 0 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = -1, .y = -1, .z = 1 }, .normal = .{ .x = -1, .y = 0, .z = 0 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = -1, .y = 1, .z = 1 }, .normal = .{ .x = -1, .y = 0, .z = 0 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = -1, .y = 1, .z = -1 }, .normal = .{ .x = -1, .y = 0, .z = 0 }, .texcoord0 = .{ 0, 0 } },
        // right (+X)
        .{ .position = .{ .x = 1, .y = -1, .z = 1 }, .normal = .{ .x = 1, .y = 0, .z = 0 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = 1, .y = -1, .z = -1 }, .normal = .{ .x = 1, .y = 0, .z = 0 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = 1, .y = 1, .z = -1 }, .normal = .{ .x = 1, .y = 0, .z = 0 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = 1, .y = 1, .z = 1 }, .normal = .{ .x = 1, .y = 0, .z = 0 }, .texcoord0 = .{ 0, 0 } },
        // top   (+Y)
        .{ .position = .{ .x = -1, .y = 1, .z = 1 }, .normal = .{ .x = 0, .y = 1, .z = 0 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = 1, .y = 1, .z = 1 }, .normal = .{ .x = 0, .y = 1, .z = 0 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = 1, .y = 1, .z = -1 }, .normal = .{ .x = 0, .y = 1, .z = 0 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = -1, .y = 1, .z = -1 }, .normal = .{ .x = 0, .y = 1, .z = 0 }, .texcoord0 = .{ 0, 0 } },
        // bottom (−Y)
        .{ .position = .{ .x = -1, .y = -1, .z = -1 }, .normal = .{ .x = 0, .y = -1, .z = 0 }, .texcoord0 = .{ 0, 1 } },
        .{ .position = .{ .x = 1, .y = -1, .z = -1 }, .normal = .{ .x = 0, .y = -1, .z = 0 }, .texcoord0 = .{ 1, 1 } },
        .{ .position = .{ .x = 1, .y = -1, .z = 1 }, .normal = .{ .x = 0, .y = -1, .z = 0 }, .texcoord0 = .{ 1, 0 } },
        .{ .position = .{ .x = -1, .y = -1, .z = 1 }, .normal = .{ .x = 0, .y = -1, .z = 0 }, .texcoord0 = .{ 0, 0 } },
    };
    const idx = [_]u16{
        0, 1, 2, 0, 2, 3, // front
        4, 5, 6, 4, 6, 7, // back
        8, 9, 10, 8, 10, 11, // left
        12, 13, 14, 12, 14, 15, // right
        16, 17, 18, 16, 18, 19, // top
        20, 21, 22, 20, 22, 23, // bottom
    };
    return initStatic(Vertex, &v, &idx, .{});
}
