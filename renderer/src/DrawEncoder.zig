/// Low-level wrapper over bgfx's stateful draw API.
/// Call set*() methods to configure state, then submit() to issue the draw call.
/// One DrawEncoder is bound to a single bgfx view_id.
/// Power users work directly with this; high-level RenderWorld uses it internally.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");
const ShaderProgram = @import("ShaderProgram.zig");
const Texture = @import("Texture.zig");
const DrawEncoder = @This();

/// Default state: depth test+write, RGB write, CCW back-face cull, MSAA.
pub const DEFAULT_STATE: u64 =
    bgfx.StateFlags_WriteRgb |
    bgfx.StateFlags_WriteA |
    bgfx.StateFlags_WriteZ |
    bgfx.StateFlags_DepthTestLess |
    //bgfx.StateFlags_CullCcw |
    bgfx.StateFlags_Msaa;

/// 2D state: no depth test/write, alpha blend, no culling.
pub const STATE_2D: u64 =
    bgfx.StateFlags_WriteRgb |
    bgfx.StateFlags_WriteA |
    // Color: SrcAlpha / InvSrcAlpha, Alpha: SrcAlpha / InvSrcAlpha
    // (5 | (6 << 4) | (5 << 8) | (6 << 12)) << 12
    0x0000000006565000;

view_id: u16,

pub fn init(view_id: u16) DrawEncoder {
    return .{ .view_id = view_id };
}

/// Set the model transform for the next draw call.
pub fn setTransform(self: DrawEncoder, model: *const math.Mat4) void {
    _ = bgfx.setTransform(&model.m, 1);
    _ = self;
}

/// Bind a static vertex buffer.
pub fn setVertexBuffer(
    self: DrawEncoder,
    vb: bgfx.VertexBufferHandle,
    first_vertex: u32,
    count: u32,
) void {
    bgfx.setVertexBuffer(0, vb, first_vertex, count);
    _ = self;
}

/// Bind a dynamic vertex buffer.
pub fn setDynamicVertexBuffer(
    self: DrawEncoder,
    vb: bgfx.DynamicVertexBufferHandle,
    first_vertex: u32,
    count: u32,
) void {
    bgfx.setDynamicVertexBuffer(0, vb, first_vertex, count);
    _ = self;
}

/// Bind a transient vertex buffer.
pub fn setTransientVertexBuffer(
    self: DrawEncoder,
    tvb: *const bgfx.TransientVertexBuffer,
    first_vertex: u32,
    count: u32,
) void {
    bgfx.setTransientVertexBuffer(0, tvb, first_vertex, count);
    _ = self;
}

/// Bind a static index buffer.
pub fn setIndexBuffer(
    self: DrawEncoder,
    ib: bgfx.IndexBufferHandle,
    first_index: u32,
    count: u32,
) void {
    bgfx.setIndexBuffer(ib, first_index, count);
    _ = self;
}

/// Bind a dynamic index buffer.
pub fn setDynamicIndexBuffer(
    self: DrawEncoder,
    ib: bgfx.DynamicIndexBufferHandle,
    first_index: u32,
    count: u32,
) void {
    bgfx.setDynamicIndexBuffer(ib, first_index, count);
    _ = self;
}

/// Bind a transient index buffer.
pub fn setTransientIndexBuffer(
    self: DrawEncoder,
    tib: *const bgfx.TransientIndexBuffer,
    first_index: u32,
    count: u32,
) void {
    bgfx.setTransientIndexBuffer(tib, first_index, count);
    _ = self;
}

/// Set a vec4 uniform value.
pub fn setVec4(self: DrawEncoder, handle: bgfx.UniformHandle, value: *const math.Vec4) void {
    bgfx.setUniform(handle, value, 1);
    _ = self;
}

/// Set a mat4 uniform value.
pub fn setMat4(self: DrawEncoder, handle: bgfx.UniformHandle, value: *const math.Mat4) void {
    bgfx.setUniform(handle, &value.m, 1);
    _ = self;
}

/// Set an array of vec4 uniforms.
pub fn setVec4Array(self: DrawEncoder, handle: bgfx.UniformHandle, values: []const math.Vec4) void {
    bgfx.setUniform(handle, values.ptr, @intCast(values.len));
    _ = self;
}

/// Set raw uniform data.
pub fn setUniformRaw(self: DrawEncoder, handle: bgfx.UniformHandle, data: *const anyopaque, count: u16) void {
    bgfx.setUniform(handle, data, count);
    _ = self;
}

/// Bind a texture to a sampler stage.
pub fn setTexture(
    self: DrawEncoder,
    stage: u8,
    sampler_handle: bgfx.UniformHandle,
    texture: bgfx.TextureHandle,
    flags: u32,
) void {
    bgfx.setTexture(stage, sampler_handle, texture, flags);
    _ = self;
}

/// Set render state flags (use DEFAULT_STATE or STATE_2D, or compose your own).
pub fn setState(self: DrawEncoder, flags: u64, rgba: u32) void {
    bgfx.setStateRgba(flags, rgba);
    _ = self;
}

/// Set render state without rgba factor (most common).
pub fn setStateDefault(self: DrawEncoder) void {
    bgfx.setState(DEFAULT_STATE, 0);
    _ = self;
}

pub fn setStateFlags(self: DrawEncoder, flags: u64) void {
    bgfx.setState(flags, 0);
    _ = self;
}

/// Touch a view (ensures it is rendered even with no draw calls — clears it).
pub fn touch(self: DrawEncoder) void {
    bgfx.touch(self.view_id);
}

/// Submit current state as a draw call to this encoder's view.
pub fn submit(self: DrawEncoder, program: ShaderProgram, depth: u32) void {
    bgfx.submit(self.view_id, program.program_handle, depth, bgfx.DiscardFlags_All);
}

/// Submit with discard flags control.
pub fn submitFlags(self: DrawEncoder, program: ShaderProgram, depth: u32, discard: u8) void {
    bgfx.submit(self.view_id, program.program_handle, depth, discard);
}

/// Submit preserving all state (no discard).
pub fn submitPreserveState(self: DrawEncoder, program: ShaderProgram) void {
    bgfx.submit(self.view_id, program.program_handle, 0, 0);
}
