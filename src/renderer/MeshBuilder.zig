const std = @import("std");
const Vertex = @import("Vertex.zig");
const Mesh = @import("Mesh.zig");
const DynamicMesh = @import("DynamicMesh.zig");
const bgfx = @import("bgfx").bgfx;
const Color = @import("../primitive/Color.zig");
const math = @import("math.zig");
const MeshBuilder = @This();
const View = @import("View.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../primitive/Image.zig");
const Font = @import("../primitive/Font.zig");

allocator: std.mem.Allocator,
vertices: std.ArrayList(Vertex),
indices: std.ArrayList(u16),

pub fn isEmpty(self: *const MeshBuilder) bool {
    return self.vertices.items.len == 0 and self.indices.items.len == 0;
}

pub fn init(allocator: std.mem.Allocator) MeshBuilder {
    return .{
        .allocator = allocator,
        .vertices = .empty,
        .indices = .empty,
    };
}

pub fn deinit(self: *MeshBuilder) void {
    self.vertices.deinit(self.allocator);
    self.indices.deinit(self.allocator);
}

pub fn reset(self: *MeshBuilder) void {
    self.vertices.clearRetainingCapacity();
    self.indices.clearRetainingCapacity();
}

pub fn baseIdx(self: *const MeshBuilder) u16 {
    return @intCast(self.vertices.items.len);
}

// all the same push methods as RenderBatch
pub fn pushVertex(self: *MeshBuilder, vertex: Vertex) void {
    self.vertices.append(self.allocator, vertex) catch unreachable;
}

pub fn pushVertices(self: *MeshBuilder, vertices: []const Vertex) void {
    self.vertices.appendSlice(self.allocator, vertices) catch unreachable;
}

pub fn pushIndex(self: *MeshBuilder, index: u16) void {
    self.indices.append(self.allocator, index) catch unreachable;
}

pub fn pushIndices(self: *MeshBuilder, indices: []const u16) void {
    self.indices.appendSlice(self.allocator, indices) catch unreachable;
}

pub fn pushTriangle(self: *MeshBuilder, a: Vertex, b: Vertex, c: Vertex) void {
    const base = self.baseIdx();
    self.pushVertices(&.{ a, b, c });
    self.pushIndices(&.{ base + 0, base + 1, base + 2 });
}

pub fn pushQuad(self: *MeshBuilder, v0: Vertex, v1: Vertex, v2: Vertex, v3: Vertex) void {
    const base = self.baseIdx();
    self.pushVertices(&.{ v0, v1, v2, v3 });
    self.pushIndices(&.{ base + 0, base + 1, base + 2, base + 0, base + 2, base + 3 });
}

pub fn pushRect(self: *MeshBuilder, x: f32, y: f32, w: f32, h: f32, color: Color) void {
    self.pushQuad(
        .init(.{ x, y, 0.0 }, color, null),
        .init(.{ x + w, y, 0.0 }, color, null),
        .init(.{ x + w, y + h, 0.0 }, color, null),
        .init(.{ x, y + h, 0.0 }, color, null),
    );
}

pub fn pushCircle(self: *MeshBuilder, cx: f32, cy: f32, radius: f32, segments: u32, color: Color) void {
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

pub fn pushTexturedRect(self: *MeshBuilder, x: f32, y: f32, w: f32, h: f32, color: Color) void {
    self.pushQuad(
        .init(.{ x, y, 0.0 }, color, .{ 0.0, 0.0 }),
        .init(.{ x + w, y, 0.0 }, color, .{ 1.0, 0.0 }),
        .init(.{ x + w, y + h, 0.0 }, color, .{ 1.0, 1.0 }),
        .init(.{ x, y + h, 0.0 }, color, .{ 0.0, 1.0 }),
    );
}
pub fn pushText(self: *MeshBuilder, font: *const Font, text: []const u8, x: f32, y: f32, color: Color) void {
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

pub fn pushLine(self: *MeshBuilder, x0: f32, y0: f32, x1: f32, y1: f32, thickness: f32, color: Color) void {
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

/// Builds a mesh from the vertices and indices stored in the builder.
pub fn buildMesh(self: *MeshBuilder, layout: *const bgfx.VertexLayout) Mesh {
    const vbh = bgfx.createVertexBuffer(
        bgfx.copy(self.vertices.items.ptr, @intCast(@sizeOf(Vertex) * self.vertices.items.len)),
        layout,
        bgfx.BufferFlags_None,
    );
    const ibh = bgfx.createIndexBuffer(
        bgfx.copy(self.indices.items.ptr, @intCast(@sizeOf(u16) * self.indices.items.len)),
        bgfx.BufferFlags_None,
    );
    return .{
        .vbh = vbh,
        .ibh = ibh,
        .num_vertices = @intCast(self.vertices.items.len),
        .num_indices = @intCast(self.indices.items.len),
    };
}

/// Builds a dynamic mesh from the vertices and indices stored in the builder.
pub fn buildDynamicMesh(self: *MeshBuilder, layout: *const bgfx.VertexLayout) DynamicMesh {
    const vbh = bgfx.createDynamicVertexBuffer(
        @intCast(self.vertices.items.len),
        layout,
        bgfx.BufferFlags_AllowResize,
    );
    const ibh = bgfx.createDynamicIndexBuffer(
        @intCast(self.indices.items.len),
        bgfx.BufferFlags_AllowResize,
    );
    var mesh = DynamicMesh{
        .vbh = vbh,
        .ibh = ibh,
        .num_vertices = @intCast(self.vertices.items.len),
        .num_indices = @intCast(self.indices.items.len),
    };
    mesh.update(self.vertices.items, self.indices.items);
    return mesh;
}

/// Submits the mesh to the view for transient rendering.
/// The mesh is not stored in the view's mesh list and is not persistent across frames.
/// The allocated transient buffer lives in the gpu memory and is freed after each frame.
/// This should be used for quads that update constantly, such as text.
pub fn submitTransient(self: *MeshBuilder, view: *View, shader: ?ShaderProgram, texture: ?*const Image, transform: ?math.Mat, blend: bool) void {
    if (self.vertices.items.len == 0) return;
    view.transient_submissions.append(self.allocator, .{
        .vertices = self.allocator.dupe(Vertex, self.vertices.items) catch unreachable,
        .indices = self.allocator.dupe(u16, self.indices.items) catch unreachable,
        .shader = shader,
        .texture = texture,
        .transform = transform,
        .blend = blend,
    }) catch unreachable;
}

pub fn submitTransient0(self: *MeshBuilder, view: *View, shader: ?ShaderProgram, texture: ?*const Image, transform: ?math.Mat) void {
    if (self.vertices.items.len == 0) return;
    view.transient_submissions.append(self.allocator, .{
        .vertices = self.allocator.dupe(Vertex, self.vertices.items) catch unreachable,
        .indices = self.allocator.dupe(u16, self.indices.items) catch unreachable,
        .shader = shader,
        .texture = texture,
        .transform = transform,
    }) catch unreachable;
}
