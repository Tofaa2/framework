/// tangents.zig
/// Generates tangents for renderer.Vertex (which already has the tangent field).
/// Call shapeToVertices() to convert a zmesh shape into a []Vertex with
/// positions, normals, UVs, and computed tangents all in one struct.
const std = @import("std");
const renderer = @import("root.zig");
pub const Vertex = renderer.Vertex; // re-export for convenience

/// Generate tangents in-place for a triangle mesh.
/// `verts` must already have position, normal, uv filled in.
pub fn generateTangents(
    allocator: std.mem.Allocator,
    verts: []Vertex,
    indices: []const u16,
) !void {
    const n = verts.len;
    var tan1 = try allocator.alloc([3]f32, n);
    var tan2 = try allocator.alloc([3]f32, n);
    defer allocator.free(tan1);
    defer allocator.free(tan2);

    for (tan1) |*t| t.* = .{ 0, 0, 0 };
    for (tan2) |*t| t.* = .{ 0, 0, 0 };

    var i: usize = 0;
    while (i < indices.len) : (i += 3) {
        const ii0 = indices[i + 0];
        const ii1 = indices[i + 1];
        const ii2 = indices[i + 2];

        const p0 = verts[ii0].position;
        const p1 = verts[ii1].position;
        const p2 = verts[ii2].position;

        const uv0 = verts[ii0].uv;
        const uv1 = verts[ii1].uv;
        const uv2 = verts[ii2].uv;

        const e1 = sub3(p1, p0);
        const e2 = sub3(p2, p0);

        const du1 = uv1[0] - uv0[0];
        const dv1 = uv1[1] - uv0[1];
        const du2 = uv2[0] - uv0[0];
        const dv2 = uv2[1] - uv0[1];

        const denom = du1 * dv2 - du2 * dv1;
        const r = if (@abs(denom) > 1e-6) 1.0 / denom else 0.0;

        const sdir = scale3(sub3(scale3(e1, dv2), scale3(e2, dv1)), r);
        const tdir = scale3(sub3(scale3(e2, du1), scale3(e1, du2)), r);

        tan1[ii0] = add3(tan1[ii0], sdir);
        tan1[ii1] = add3(tan1[ii1], sdir);
        tan1[ii2] = add3(tan1[ii2], sdir);

        tan2[ii0] = add3(tan2[ii0], tdir);
        tan2[ii1] = add3(tan2[ii1], tdir);
        tan2[ii2] = add3(tan2[ii2], tdir);
    }

    for (verts, 0..) |*v, idx| {
        const N = v.normal;
        const T = tan1[idx];
        const NdotT = dot3(N, T);
        const t_orth = normalize3(sub3(T, scale3(N, NdotT)));
        const handedness: f32 = if (dot3(cross3(N, T), tan2[idx]) < 0.0) -1.0 else 1.0;
        v.tangent = .{ t_orth[0], t_orth[1], t_orth[2], handedness };
    }
}

/// Convert a zmesh shape into a []Vertex slice with computed tangents.
/// Caller owns the returned slice.
pub fn shapeToVertices(
    allocator: std.mem.Allocator,
    positions: [][3]f32,
    normals: ?[][3]f32,
    texcoords: ?[][2]f32,
    indices: []const u16,
    color: u32,
) ![]Vertex {
    const verts = try allocator.alloc(Vertex, positions.len);

    for (verts, 0..) |*v, i| {
        v.position = positions[i];
        v.normal = if (normals) |n| n[i] else .{ 0, 1, 0 };
        v.uv = if (texcoords) |t| t[i] else .{ 0, 0 };
        v.color = color;
        v.tangent = .{ 1, 0, 0, 1 }; // default, overwritten below if UVs present
    }

    if (texcoords != null) {
        try generateTangents(allocator, verts, indices);
    }

    return verts;
}

// ── Math helpers ─────────────────────────────────────────────

fn add3(a: [3]f32, b: [3]f32) [3]f32 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}
fn sub3(a: [3]f32, b: [3]f32) [3]f32 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}
fn scale3(a: [3]f32, s: f32) [3]f32 {
    return .{ a[0] * s, a[1] * s, a[2] * s };
}
fn dot3(a: [3]f32, b: [3]f32) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}
fn cross3(a: [3]f32, b: [3]f32) [3]f32 {
    return .{ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
}
fn normalize3(a: [3]f32) [3]f32 {
    const len = @sqrt(dot3(a, a));
    return if (len < 1e-6) .{ 0, 0, 0 } else scale3(a, 1.0 / len);
}
