/// Represents a dynamic mesh, a mesh thats buffer is submitted to the gpu once and then the bytes are updated dynamically.
/// The difference between this and just submitting a MeshBuilder directly is that this buffer isnt allocated each frame and doesnt have a fixed limit in size
/// This is a preferred option to use when you are rendering a mesh that will be updated frequently but not constantly, such as a player model.
const bgfx = @import("bgfx").bgfx;
const Vertex = @import("Vertex.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../assets/Image.zig");
const math = @import("math.zig");
const DynamicMesh = @This();
const Material = @import("../assets/Material.zig");

vbh: bgfx.DynamicVertexBufferHandle,
ibh: bgfx.DynamicIndexBufferHandle,
num_vertices: u32,
num_indices: u32,
texture: ?*const Image = null,
material: ?*const Material = null,
transform: ?math.Mat = null,
owned_texture: ?Image = null,

pub fn update(self: *DynamicMesh, vertices: []const Vertex, indices: []const u16) void {
    bgfx.updateDynamicVertexBuffer(self.vbh, 0, bgfx.copy(
        vertices.ptr,
        @intCast(@sizeOf(Vertex) * vertices.len),
    ));
    bgfx.updateDynamicIndexBuffer(self.ibh, 0, bgfx.copy(
        indices.ptr,
        @intCast(@sizeOf(u16) * indices.len),
    ));
    self.num_vertices = @intCast(vertices.len);
    self.num_indices = @intCast(indices.len);
}

pub fn deinit(self: *DynamicMesh) void {
    bgfx.destroyDynamicVertexBuffer(self.vbh);
    bgfx.destroyDynamicIndexBuffer(self.ibh);
    if (self.owned_texture) |*tex| tex.deinit();
}
