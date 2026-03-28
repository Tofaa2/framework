/// Represents a static mesh, a mesh that is stored in the view's mesh list and is persistent across frames.
/// Its the users responsibility to free the mesh when it is no longer needed.
/// Should be used when the mesh is not expected to be modified after creation.
/// Such as for static geometry, terrain, or other non-dynamic meshes.
const bgfx = @import("bgfx").bgfx;
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../assets/Image.zig");
const math = @import("math.zig");
const Mesh = @This();
const Material = @import("../assets/Material.zig");
const Handle = @import("../core/AssetPool.zig").Handle;
const MeshBuilder = @import("MeshBuilder.zig");
const ObjLoader = @import("ObjLoader.zig");
const Vertex = @import("Vertex.zig");

vbh: bgfx.VertexBufferHandle,
ibh: bgfx.IndexBufferHandle,
num_vertices: u32,
num_indices: u32,
material: ?*Material = null,
texture: Handle(Image) = .invalid,
transform: ?math.Mat = null,

bounding_radius: f32 = 1.0,
bounding_center: [3]f32 = .{ 0.0, 0.0, 0.0 },

pub fn deinit(self: *Mesh) void {
    bgfx.destroyVertexBuffer(self.vbh);
    bgfx.destroyIndexBuffer(self.ibh);
}

const std = @import("std");

pub fn buildFromSlices(
    vertices: []const Vertex,
    indices: []const u16,
    layout: *const bgfx.VertexLayout,
) Mesh {
    const vbh = bgfx.createVertexBuffer(
        bgfx.copy(vertices.ptr, @intCast(@sizeOf(Vertex) * vertices.len)),
        layout,
        bgfx.BufferFlags_None,
    );
    const ibh = bgfx.createIndexBuffer(
        bgfx.copy(indices.ptr, @intCast(@sizeOf(u16) * indices.len)),
        bgfx.BufferFlags_None,
    );
    return Mesh{
        .vbh = vbh,
        .ibh = ibh,
        .num_vertices = @intCast(vertices.len),
        .num_indices = @intCast(indices.len),
    };
}
