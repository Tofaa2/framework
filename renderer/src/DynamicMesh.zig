const bgfx = @import("bgfx").bgfx;
const DynamicMesh = @This();


vbh: bgfx.DynamicVertexBufferHandle,
    ibh: bgfx.DynamicIndexBufferHandle,
    layout: bgfx.VertexLayout,
    vertex_count: u32,
    index_count: u32,

    pub fn deinit(self: *DynamicMesh) void {
        bgfx.destroyDynamicVertexBuffer(self.vbh);
        bgfx.destroyDynamicIndexBuffer(self.ibh);
    }
