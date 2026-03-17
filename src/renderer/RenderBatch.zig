const std = @import("std");
const math = @import("math.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Vertex = @import("Vertex.zig");
const Image = @import("Image.zig");
const RenderBatch = @This();

allocator: std.mem.Allocator,

vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u16),
shader: ?ShaderProgram,
texture: ?Image,
transform: ?math.Mat,

/// TODO: Implement these
/// The idea is to optimize for meshes (VertexBufferHandle, IndexBufferHandle)
/// Text rendering (TransientVertexBuffer, TransientIndexBuffer)
/// Generic dynamic geometry (DynamicVertexBuffer, DynamicIndexBuffer)
is_transient: bool = false,
is_static: bool = false,

pub fn init(allocator: std.mem.Allocator, shader: ?ShaderProgram, texture: ?Image) RenderBatch {
    return .{
        .allocator = allocator,
        .vertices = .empty,
        .indices = .empty,
        .shader = shader,
        .texture = texture,
        .transform = null,
    };
}

pub fn pushVertex(self: *RenderBatch, vertex: Vertex) void {
    self.vertices.append(self.allocator, vertex) catch unreachable;
}

pub fn pushVertices(self: *RenderBatch, vertices: []const Vertex) void {
    self.vertices.appendSlice(self.allocator, vertices) catch unreachable;
}

pub fn pushIndex(self: *RenderBatch, index: u16) void {
    self.indices.append(self.allocator, index) catch unreachable;
}

pub fn pushIndices(self: *RenderBatch, indices: []const u16) void {
    self.indices.appendSlice(self.allocator, indices) catch unreachable;
}

pub fn pushTriangle(self: *RenderBatch, a: Vertex, b: Vertex, c: Vertex) void {
    const base_index = self.baseIdx();

    self.pushVertices(&.{ a, b, c });
    self.pushIndices(&.{ base_index + 0, base_index + 1, base_index + 2 });
}

pub fn pushQuad(self: *RenderBatch, v0: Vertex, v1: Vertex, v2: Vertex, v3: Vertex) void {
    const base = self.baseIdx();

    self.pushVertices(&.{ v0, v1, v2, v3 });
    self.pushIndices(&.{ base + 0, base + 1, base + 2, base + 0, base + 2, base + 3 });
}

pub fn baseIdx(self: *const RenderBatch) u16 {
    return @as(u16, @intCast(self.vertices.items.len));
}
