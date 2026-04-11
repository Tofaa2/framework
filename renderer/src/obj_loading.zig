const std = @import("std");
const bgfx = @import("bgfx").bgfx;
pub const zmesh = @import("zmesh");
const StaticMesh = @import("StaticMesh.zig");
const Renderer = @import("Renderer.zig");

pub const ShapeVertex = struct {
    position: [3]f32,
    normal: [3]f32,
    texcoord0: [2]f32,
};

pub fn shapeToStaticMesh(
    allocator: std.mem.Allocator,
    shape: zmesh.Shape,
) StaticMesh {
    const len = shape.positions.len;

    var vertices: std.ArrayList(ShapeVertex) = .empty;
    defer vertices.deinit(allocator);

    for (0..len) |i| {
        const position = shape.positions[i];

        const uv: [2]f32 = if (shape.texcoords) |tex| tex[i] else .{ 0.0, 0.0 };
        const normals: [3]f32 = if (shape.normals) |normal| normal[i] else .{ 0.0, 0.0, 0.0 };

        vertices.append(allocator, .{
            .normal = normals,
            .position = position,
            .texcoord0 = uv,
        }) catch unreachable;
    }

    var indices: std.ArrayList(u16) = .empty;
    defer indices.deinit(allocator);
    for (0..shape.indices.len) |i| {
        indices.append(allocator, @intCast(shape.indices[i])) catch unreachable;
    }

    const vert_slice = vertices.toOwnedSlice(allocator) catch unreachable;
    defer allocator.free(vert_slice);
    const index_slice = indices.toOwnedSlice(allocator) catch unreachable;
    defer allocator.free(index_slice);

    const layout = @import("vertex_parser.zig").createLayout(ShapeVertex, .{}, bgfx.getRendererType());

    const vb_mem = bgfx.copy(vert_slice.ptr, @intCast(@sizeOf(ShapeVertex) * vert_slice.len));
    const ib_mem = bgfx.copy(index_slice.ptr, @intCast(@sizeOf(i16) * index_slice.len));

    const ib = bgfx.createIndexBuffer(ib_mem, bgfx.BufferFlags_None);
    const vb = bgfx.createVertexBuffer(vb_mem, &layout, bgfx.BufferFlags_None);
    return .{
        .layout = layout,
        .ibh = ib,
        .vbh = vb,
    };
}
