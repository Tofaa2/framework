const std = @import("std");
const math = @import("math.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Vertex = @import("Vertex.zig");
const Image = @import("../primitive/Image.zig");
const RenderBatch = @This();
const Color = @import("../primitive/Color.zig");
const Font = @import("../primitive/Font.zig");
allocator: std.mem.Allocator,

vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u16),
shader: ?ShaderProgram,
texture: ?*const Image,
transform: ?math.Mat,

/// TODO: Implement these
/// The idea is to optimize for meshes (VertexBufferHandle, IndexBufferHandle)
/// Text rendering (TransientVertexBuffer, TransientIndexBuffer)
/// Generic dynamic geometry (DynamicVertexBuffer, DynamicIndexBuffer)
is_transient: bool = false,
is_static: bool = false,

pub fn isEmpty(self: *const RenderBatch) bool {
    return self.vertices.items.len == 0 and self.indices.items.len == 0;
}

pub fn init(allocator: std.mem.Allocator, shader: ?ShaderProgram, texture: ?*const Image) RenderBatch {
    return .{
        .allocator = allocator,
        .vertices = .empty,
        .indices = .empty,
        .shader = shader,
        .texture = texture,
        .transform = null,
    };
}
pub fn pushTexturedRect(self: *RenderBatch, x: f32, y: f32, w: f32, h: f32, color: Color) void {
    self.pushQuad(
        .init(.{ x, y, 0.0 }, color, .{ 0.0, 0.0 }),
        .init(.{ x + w, y, 0.0 }, color, .{ 1.0, 0.0 }),
        .init(.{ x + w, y + h, 0.0 }, color, .{ 1.0, 1.0 }),
        .init(.{ x, y + h, 0.0 }, color, .{ 0.0, 1.0 }),
    );
}
pub fn pushText(self: *RenderBatch, font: *const Font, text: []const u8, x: f32, y: f32, color: Color) void {
    var cursor_x = x;
    for (text) |char| {
        const glyph = font.getGlyph(char) orelse continue;
        const x0 = cursor_x + glyph.x_offset;
        const y0 = y + glyph.y_offset;
        const x1 = x0 + glyph.width;
        const y1 = y0 + glyph.height;

        self.pushQuad(
            .init(.{ x0, y0, 0.0 }, color, .{ glyph.u0, glyph.v1 }),
            .init(.{ x1, y0, 0.0 }, color, .{ glyph.u1, glyph.v1 }),
            .init(.{ x1, y1, 0.0 }, color, .{ glyph.u1, glyph.v0 }),
            .init(.{ x0, y1, 0.0 }, color, .{ glyph.u0, glyph.v0 }),
        );

        cursor_x += glyph.x_advance;
    }
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

pub fn pushRect(self: *RenderBatch, x: f32, y: f32, w: f32, h: f32, color: Color) void {
    self.pushQuad(
        .init(.{ x, y, 0.0 }, color, null),
        .init(.{ x + w, y, 0.0 }, color, null),
        .init(.{ x + w, y + h, 0.0 }, color, null),
        .init(.{ x, y + h, 0.0 }, color, null),
    );
}

pub fn pushLine(self: *RenderBatch, x0: f32, y0: f32, x1: f32, y1: f32, thickness: f32, color: Color) void {
    const dx = x1 - x0;
    const dy = y1 - y0;
    const len = @sqrt(dx * dx + dy * dy);
    // perpendicular normal
    const nx = (-dy / len) * (thickness * 0.5);
    const ny = (dx / len) * (thickness * 0.5);

    self.pushQuad(
        .init(.{ x0 - nx, y0 - ny, 0.0 }, color, null),
        .init(.{ x1 - nx, y1 - ny, 0.0 }, color, null),
        .init(.{ x1 + nx, y1 + ny, 0.0 }, color, null),
        .init(.{ x0 + nx, y0 + ny, 0.0 }, color, null),
    );
}

pub fn pushCircle(self: *RenderBatch, cx: f32, cy: f32, radius: f32, segments: u32, color: Color) void {
    const base = self.baseIdx();
    // center vertex
    self.pushVertex(.init(.{ cx, cy, 0.0 }, color, null));

    // ring vertices
    var i: u32 = 0;
    while (i <= segments) : (i += 1) {
        const angle = (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments))) * std.math.tau;
        const x = cx + @cos(angle) * radius;
        const y = cy + @sin(angle) * radius;
        self.pushVertex(.init(.{ x, y, 0.0 }, color, null));
    }

    // indices: center + each pair of ring vertices forms a triangle
    i = 0;
    while (i < segments) : (i += 1) {
        self.pushIndices(&.{
            base, // center
            base + 1 + @as(u16, @intCast(i)),
            base + 2 + @as(u16, @intCast(i)),
        });
    }
}

pub fn baseIdx(self: *const RenderBatch) u16 {
    return @as(u16, @intCast(self.vertices.items.len));
}
