const Mesh = @This();
const bgfx = @import("bgfx.zig");
const Vertex = @import("Vertex.zig");

vbh: bgfx.VertexBufferHandle,
ibh: bgfx.IndexBufferHandle,

pub fn create(vertices: []const Vertex, indices: []const u16) Mesh {
    const mem_v = bgfx.copy(vertices.ptr, @intCast(vertices.len * @sizeOf(Vertex)));
    const mem_i = bgfx.copy(indices.ptr, @intCast(indices.len * @sizeOf(u16)));
    return .{
        .vbh = bgfx.createVertexBuffer(mem_v, &Vertex.layout, bgfx.BufferFlags_None),
        .ibh = bgfx.createIndexBuffer(mem_i, bgfx.BufferFlags_None),
    };
}

pub fn destroy(self: *const Mesh) void {
    bgfx.destroyVertexBuffer(self.vbh);
    bgfx.destroyIndexBuffer(self.ibh);
}
