const StaticMesh = @This();
const bgfx = @import("bgfx").bgfx;

    vbh: bgfx.VertexBufferHandle,
    ibh: bgfx.IndexBufferHandle,
    layout: bgfx.VertexLayout,

    pub fn deinit(self: *StaticMesh) void {
        bgfx.destroyVertexBuffer(self.vbh);
        bgfx.destroyIndexBuffer(self.ibh);
    }

