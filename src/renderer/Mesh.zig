/// Represents a static mesh, a mesh that is stored in the view's mesh list and is persistent across frames.
/// Its the users responsibility to free the mesh when it is no longer needed.
/// Should be used when the mesh is not expected to be modified after creation.
/// Such as for static geometry, terrain, or other non-dynamic meshes.
const bgfx = @import("bgfx").bgfx;
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../primitive/Image.zig");
const math = @import("math.zig");
const Mesh = @This();

vbh: bgfx.VertexBufferHandle,
ibh: bgfx.IndexBufferHandle,
num_vertices: u32,
num_indices: u32,
shader: ?ShaderProgram = null,
texture: ?*const Image = null,
transform: ?math.Mat = null,

pub fn deinit(self: *Mesh) void {
    bgfx.destroyVertexBuffer(self.vbh);
    bgfx.destroyIndexBuffer(self.ibh);
}
