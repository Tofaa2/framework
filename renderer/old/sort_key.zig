/// sort_key.zig
/// Packed u64 sort key. Sorts draw calls within a pass to minimise state changes
/// and handle transparency correctly.
///
/// Bit layout (MSB → LSB):
///   [63:56]  pass   (u8)   — coarse ordering: shadow < geometry < particles < ui < post
///   [55:48]  layer  (u8)   — sub-ordering within pass (e.g. opaque=0, alpha=1)
///   [47:32]  material (u16)— batch by material to reduce state changes
///   [31:16]  mesh   (u16)  — secondary batch key
///   [15:0]   depth  (u16)  — for transparent layers: back-to-front (inverted z)

const std = @import("std");

pub const Pass = enum(u8) {
    Shadow = 0,
    Geometry = 1,
    Particles = 2,
    UI = 3,
    Post = 4,
};

pub const Layer = enum(u8) {
    Opaque = 0,
    AlphaTest = 1,
    Transparent = 2,
    Overlay = 3,
};

pub const SortKey = packed struct(u64) {
    depth: u16,
    mesh: u16,
    material: u16,
    layer: u8,
    pass: u8,

    pub fn encode(self: SortKey) u64 {
        return @bitCast(self);
    }

    pub fn decode(v: u64) SortKey {
        return @bitCast(v);
    }

    /// For opaque geometry: sort front-to-back (small depth first = closer to camera).
    /// For transparent geometry: sort back-to-front (large depth first).
    pub fn forOpaque(pass: Pass, material_idx: u16, mesh_idx: u16, linear_depth_01: f32) SortKey {
        return .{
            .pass = @intFromEnum(pass),
            .layer = @intFromEnum(Layer.Opaque),
            .material = material_idx,
            .mesh = mesh_idx,
            .depth = depthFrontToBack(linear_depth_01),
        };
    }

    pub fn forTransparent(pass: Pass, material_idx: u16, mesh_idx: u16, linear_depth_01: f32) SortKey {
        return .{
            .pass = @intFromEnum(pass),
            .layer = @intFromEnum(Layer.Transparent),
            .material = material_idx,
            .mesh = mesh_idx,
            .depth = depthBackToFront(linear_depth_01),
        };
    }

    pub fn forUI(material_idx: u16, draw_order: u16) SortKey {
        return .{
            .pass = @intFromEnum(Pass.UI),
            .layer = @intFromEnum(Layer.Overlay),
            .material = material_idx,
            .mesh = 0,
            .depth = draw_order,
        };
    }

    fn depthFrontToBack(d: f32) u16 {
        const clamped = std.math.clamp(d, 0.0, 1.0);
        return @intFromFloat(clamped * @as(f32, std.math.maxInt(u16)));
    }

    fn depthBackToFront(d: f32) u16 {
        return std.math.maxInt(u16) - depthFrontToBack(d);
    }
};

/// Sort a slice of (key, draw_index) pairs by key ascending.
pub fn sortDrawCalls(pairs: []DrawPair) void {
    std.sort.pdq(DrawPair, pairs, {}, struct {
        fn lessThan(_: void, a: DrawPair, b: DrawPair) bool {
            return a.key < b.key;
        }
    }.lessThan);
}

pub const DrawPair = struct {
    key: u64,
    index: u32, // index into draw call list
};
