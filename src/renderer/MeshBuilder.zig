const std = @import("std");
const Vertex = @import("Vertex.zig");
const Mesh = @import("Mesh.zig");
const DynamicMesh = @import("DynamicMesh.zig");
const bgfx = @import("bgfx").bgfx;
const Color = @import("../components/Color.zig");
const math = @import("math.zig");
const MeshBuilder = @This();
const View = @import("View.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../assets/Image.zig");
const Font = @import("../assets/Font.zig");

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
        const x1 = x0 + glyph.width;

        const y0 = y + glyph.y_offset + font.ascent;
        const y1 = y0 + glyph.height;
        self.pushQuad(
            .init(.{ x0, y0, 0.0 }, color, .{ glyph.u0, glyph.v0 }),
            .init(.{ x1, y0, 0.0 }, color, .{ glyph.u1, glyph.v0 }),
            .init(.{ x1, y1, 0.0 }, color, .{ glyph.u1, glyph.v1 }),
            .init(.{ x0, y1, 0.0 }, color, .{ glyph.u0, glyph.v1 }),
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
pub fn pushPlane(self: *MeshBuilder, cx: f32, cy: f32, cz: f32, size_x: f32, size_z: f32, color: Color) void {
    const hx = size_x * 0.5;
    const hz = size_z * 0.5;
    const n: [3]f32 = .{ 0.0, 1.0, 0.0 }; // facing up
    self.pushQuad(
        .initWithNormal(.{ cx - hx, cy, cz + hz }, color, .{ 0.0, 0.0 }, n),
        .initWithNormal(.{ cx + hx, cy, cz + hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx + hx, cy, cz - hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx - hx, cy, cz - hz }, color, .{ 0.0, 1.0 }, n),
    );
}

pub fn pushCube(self: *MeshBuilder, cx: f32, cy: f32, cz: f32, size_x: f32, size_y: f32, size_z: f32, color: Color) void {
    const hx = size_x * 0.5;
    const hy = size_y * 0.5;
    const hz = size_z * 0.5;

    // Front face (+Z)
    var n: [3]f32 = .{ 0.0, 0.0, 1.0 };
    self.pushQuad(
        .initWithNormal(.{ cx - hx, cy + hy, cz + hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy + hy, cz + hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz + hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx - hx, cy - hy, cz + hz }, color, .{ 0.0, 0.0 }, n),
    );
    // Back face (-Z)
    n = .{ 0.0, 0.0, -1.0 };
    self.pushQuad(
        .initWithNormal(.{ cx + hx, cy + hy, cz - hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx - hx, cy + hy, cz - hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx - hx, cy - hy, cz - hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz - hz }, color, .{ 0.0, 0.0 }, n),
    );
    // Top face (+Y)
    n = .{ 0.0, 1.0, 0.0 };
    self.pushQuad(
        .initWithNormal(.{ cx - hx, cy + hy, cz - hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy + hy, cz - hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy + hy, cz + hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx - hx, cy + hy, cz + hz }, color, .{ 0.0, 0.0 }, n),
    );
    // Bottom face (-Y)
    n = .{ 0.0, -1.0, 0.0 };
    self.pushQuad(
        .initWithNormal(.{ cx - hx, cy - hy, cz + hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz + hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz - hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx - hx, cy - hy, cz - hz }, color, .{ 0.0, 0.0 }, n),
    );
    // Right face (+X)
    n = .{ 1.0, 0.0, 0.0 };
    self.pushQuad(
        .initWithNormal(.{ cx + hx, cy + hy, cz + hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy + hy, cz - hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz - hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx + hx, cy - hy, cz + hz }, color, .{ 0.0, 0.0 }, n),
    );
    // Left face (-X)
    n = .{ -1.0, 0.0, 0.0 };
    self.pushQuad(
        .initWithNormal(.{ cx - hx, cy + hy, cz - hz }, color, .{ 0.0, 1.0 }, n),
        .initWithNormal(.{ cx - hx, cy + hy, cz + hz }, color, .{ 1.0, 1.0 }, n),
        .initWithNormal(.{ cx - hx, cy - hy, cz + hz }, color, .{ 1.0, 0.0 }, n),
        .initWithNormal(.{ cx - hx, cy - hy, cz - hz }, color, .{ 0.0, 0.0 }, n),
    );
}

pub fn pushSphere(self: *MeshBuilder, cx: f32, cy: f32, cz: f32, radius: f32, rings: u32, slices: u32, color: Color) void {
    const base = self.baseIdx();

    var i: u32 = 0;
    while (i <= rings) : (i += 1) {
        const phi = (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(rings))) * std.math.pi;
        const sin_phi = @sin(phi);
        const cos_phi = @cos(phi);

        var j: u32 = 0;
        while (j <= slices) : (j += 1) {
            const theta = (@as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(slices))) * std.math.tau;
            const sin_theta = @sin(theta);
            const cos_theta = @cos(theta);

            const nx = sin_phi * cos_theta;
            const ny = cos_phi;
            const nz = sin_phi * sin_theta;

            const x = cx + radius * nx;
            const y = cy + radius * ny;
            const z = cz + radius * nz;

            const u = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(slices));
            const v = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(rings));

            self.pushVertex(.initWithNormal(.{ x, y, z }, color, .{ u, v }, .{ nx, ny, nz }));
        }
    }
    // indices stay the same
    i = 0;
    while (i < rings) : (i += 1) {
        var j: u32 = 0;
        while (j < slices) : (j += 1) {
            const next_i = i + 1;
            const next_j = j + 1;

            const p0 = base + @as(u16, @intCast(i * (slices + 1) + j));
            const p1 = base + @as(u16, @intCast(i * (slices + 1) + next_j));
            const p2 = base + @as(u16, @intCast(next_i * (slices + 1) + j));
            const p3 = base + @as(u16, @intCast(next_i * (slices + 1) + next_j));

            self.pushIndices(&.{ p0, p2, p1 });
            self.pushIndices(&.{ p1, p2, p3 });
        }
    }
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

    // compute bounding sphere
    var cx: f32 = 0;
    var cy: f32 = 0;
    var cz: f32 = 0;
    const count: f32 = @floatFromInt(self.vertices.items.len);

    // find centroid
    for (self.vertices.items) |v| {
        cx += v.position[0];
        cy += v.position[1];
        cz += v.position[2];
    }
    cx /= count;
    cy /= count;
    cz /= count;

    // find max distance from centroid
    var max_r: f32 = 0;
    for (self.vertices.items) |v| {
        const dx = v.position[0] - cx;
        const dy = v.position[1] - cy;
        const dz = v.position[2] - cz;
        max_r = @max(max_r, @sqrt(dx * dx + dy * dy + dz * dz));
    }

    return .{
        .vbh = vbh,
        .ibh = ibh,
        .num_vertices = @intCast(self.vertices.items.len),
        .num_indices = @intCast(self.indices.items.len),
        .bounding_center = .{ cx, cy, cz },
        .bounding_radius = max_r,
    };
}

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

    // compute bounding sphere
    var cx: f32 = 0;
    var cy: f32 = 0;
    var cz: f32 = 0;
    const count: f32 = @floatFromInt(vertices.len);

    // find centroid
    for (vertices) |v| {
        cx += v.position[0];
        cy += v.position[1];
        cz += v.position[2];
    }
    cx /= count;
    cy /= count;
    cz /= count;

    // find max distance from centroid
    var max_r: f32 = 0;
    for (vertices) |v| {
        const dx = v.position[0] - cx;
        const dy = v.position[1] - cy;
        const dz = v.position[2] - cz;
        max_r = @max(max_r, @sqrt(dx * dx + dy * dy + dz * dz));
    }

    return Mesh{
        .vbh = vbh,
        .ibh = ibh,
        .num_vertices = @intCast(vertices.len),
        .num_indices = @intCast(indices.len),
        .bounding_center = [3]f32{ cx, cy, cz },
        .bounding_radius = max_r,
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
