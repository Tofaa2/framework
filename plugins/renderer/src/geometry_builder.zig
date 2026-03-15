//! GeometryBuilder — batched 2D/3D primitive builder for bgfx
//!
//! Usage:
//!   var b = GeometryBuilder.init(allocator);
//!   defer b.deinit();
//!
//!   // 3D
//!   try b.addCube(.{ .pos = .{0,0,0}, .size = 1.0, .color = .red });
//!   try b.addSphere(.{ .pos = .{3,0,0}, .radius = 0.5, .segments = 16, .stacks = 8 });
//!
//!   // 2D (z=0, orthographic)
//!   try b.addRect2D(.{ .x=-0.5, .y=-0.5, .w=1, .h=1, .color = .white });
//!   try b.addCircle2D(.{ .cx=0, .cy=0, .r=0.5, .segments=32, .color = .cyan });
//!
//!   // Flush — creates one VB + one IB, one draw call per view
//!   const mesh = try b.flush(layout, view_id, program_handle);
//!   defer mesh.deinit();

const std = @import("std");
pub const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;
const zm = @import("math.zig");
const Color = @import("Color.zig");
const isValid = @import("bgfx_util.zig").isValid;

// ─── Vertex ──────────────────────────────────────────────────────────────────
pub const Vertex = @import("Vertex.zig");

// ─── Built mesh ──────────────────────────────────────────────────────────────

pub const Mesh = struct {
    vbh: bgfx.VertexBufferHandle,
    ibh: bgfx.IndexBufferHandle,
    index_count: u32,

    pub fn deinit(self: *Mesh) void {
        bgfx.destroyVertexBuffer(self.vbh);
        bgfx.destroyIndexBuffer(self.ibh);
    }

    /// Submit this mesh to bgfx. Call once per frame.
    pub fn submit(
        self: *const Mesh,
        view_id: u8,
        program: bgfx.ProgramHandle,
        state_flags: u64,
        texture: ?bgfx.TextureHandle,
        tex_uniform: ?bgfx.UniformHandle,
    ) void {
        if (texture) |tex| {
            if (tex_uniform) |u| {
                bgfx.setTexture(0, u, tex, std.math.maxInt(u32));
            }
        }
        bgfx.setVertexBuffer(0, self.vbh, 0, @intCast(self.index_count)); // vertex count
        bgfx.setIndexBuffer(self.ibh, 0, @intCast(self.index_count));
        bgfx.setState(state_flags, 0);
        _ = bgfx.submit(view_id, program, 0, bgfx.DiscardFlags_All);
    }
};

// ─── Transform helpers ───────────────────────────────────────────────────────

pub const Transform3D = struct {
    pos: [3]f32 = .{ 0, 0, 0 },
    rot: [3]f32 = .{ 0, 0, 0 }, // euler XYZ radians
    scale: [3]f32 = .{ 1, 1, 1 },

    pub fn toMatrix(self: Transform3D) zm.Mat {
        const s = zm.scaling(self.scale[0], self.scale[1], self.scale[2]);
        const rx = zm.rotationX(self.rot[0]);
        const ry = zm.rotationY(self.rot[1]);
        const rz = zm.rotationZ(self.rot[2]);
        const t = zm.translation(self.pos[0], self.pos[1], self.pos[2]);
        return zm.mul(zm.mul(zm.mul(zm.mul(s, rx), ry), rz), t);
    }
};

// ─── Primitive option structs ─────────────────────────────────────────────────

pub const CubeOptions = struct {
    transform: Transform3D = .{},
    size: f32 = 1.0,
    color: Color = .white,
    uv_scale: f32 = 1.0,
};

pub const SphereOptions = struct {
    transform: Transform3D = .{},
    radius: f32 = 1.0,
    segments: u32 = 16,
    stacks: u32 = 8,
    color: Color = .white,
};

pub const CylinderOptions = struct {
    transform: Transform3D = .{},
    radius: f32 = 0.5,
    height: f32 = 2.0,
    segments: u32 = 16,
    color: Color = .white,
    caps: bool = true,
};

pub const ConeOptions = struct {
    transform: Transform3D = .{},
    radius: f32 = 0.5,
    height: f32 = 2.0,
    segments: u32 = 16,
    color: Color = .white,
    cap: bool = true,
};

pub const TorusOptions = struct {
    transform: Transform3D = .{},
    major_radius: f32 = 1.0,
    minor_radius: f32 = 0.3,
    major_segments: u32 = 24,
    minor_segments: u32 = 12,
    color: Color = .white,
};

pub const PlaneOptions = struct {
    transform: Transform3D = .{},
    width: f32 = 1.0,
    depth: f32 = 1.0,
    subdivide_w: u32 = 1,
    subdivide_d: u32 = 1,
    color: Color = .white,
    uv_scale: f32 = 1.0,
};

// 2D
pub const RectOptions = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 1,
    h: f32 = 1,
    color: Color = .white,
    uv: [4][2]f32 = .{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } },
};

pub const CircleOptions = struct {
    cx: f32 = 0,
    cy: f32 = 0,
    radius: f32 = 0.5,
    segments: u32 = 32,
    color: Color = .white,
};

pub const RingOptions = struct {
    cx: f32 = 0,
    cy: f32 = 0,
    outer_radius: f32 = 0.5,
    inner_radius: f32 = 0.25,
    segments: u32 = 32,
    color: Color = .white,
};

pub const LineOptions = struct {
    x0: f32 = 0,
    y0: f32 = 0,
    x1: f32 = 1,
    y1: f32 = 0,
    thickness: f32 = 0.01,
    color: Color = .white,
};

pub const NgonOptions = struct {
    cx: f32 = 0,
    cy: f32 = 0,
    radius: f32 = 0.5,
    sides: u32 = 6,
    color: Color = .white,
};

pub const StarOptions = struct {
    cx: f32 = 0,
    cy: f32 = 0,
    outer_radius: f32 = 0.5,
    inner_radius: f32 = 0.25,
    points: u32 = 5,
    color: Color = .white,
};

pub const QuadUVOptions = struct {
    tl: [2]f32 = .{ -1, 1 },
    tr: [2]f32 = .{ 1, 1 },
    bl: [2]f32 = .{ -1, -1 },
    br: [2]f32 = .{ 1, -1 },
    uv_tl: [2]f32 = .{ 0, 0 },
    uv_tr: [2]f32 = .{ 1, 0 },
    uv_bl: [2]f32 = .{ 0, 1 },
    uv_br: [2]f32 = .{ 1, 1 },
    color: Color = .white,
};

// ─── GeometryBuilder ─────────────────────────────────────────────────────────

pub const GeometryBuilder = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u16),

    pub fn init(allocator: std.mem.Allocator) GeometryBuilder {
        return .{
            .allocator = allocator,
            .vertices = .empty,
            .indices = .empty,
        };
    }

    pub fn deinit(self: *GeometryBuilder) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
    }

    /// Clear accumulated geometry without freeing backing memory.
    pub fn reset(self: *GeometryBuilder) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
    }

    /// Upload to GPU and return a Mesh. Builder can be reset/reused after this.
    pub fn flush(
        self: *GeometryBuilder,
        layout: *const bgfx.VertexLayout,
    ) !Mesh {
        if (self.vertices.items.len == 0) return error.EmptyGeometry;

        const vm = bgfx.makeRef(
            self.vertices.items.ptr,
            @intCast(@sizeOf(Vertex) * self.vertices.items.len),
        );
        const vbh = bgfx.createVertexBuffer(vm, layout, bgfx.BufferFlags_None);
        if (!isValid(vbh)) return error.InvalidVertexBuffer;

        const im = bgfx.makeRef(
            self.indices.items.ptr,
            @intCast(@sizeOf(u16) * self.indices.items.len),
        );
        const ibh = bgfx.createIndexBuffer(im, bgfx.BufferFlags_None);
        if (!isValid(ibh)) return error.InvalidIndexBuffer;

        return Mesh{
            .vbh = vbh,
            .ibh = ibh,
            .index_count = @intCast(self.indices.items.len),
        };
    }

    // ── internal helpers ─────────────────────────────────────────────────────

    fn base(self: *const GeometryBuilder) u16 {
        return @intCast(self.vertices.items.len);
    }

    fn pushVertex(self: *GeometryBuilder, v: Vertex) !void {
        try self.vertices.append(self.allocator, v);
    }

    fn pushTri(self: *GeometryBuilder, a: u16, b: u16, c: u16) !void {
        try self.indices.append(
            self.allocator,
            a,
        );
        try self.indices.append(
            self.allocator,
            b,
        );
        try self.indices.append(
            self.allocator,
            c,
        );
    }

    /// Apply a Transform3D matrix to a local-space position.
    fn applyTransform(pos: [3]f32, mtx: zm.Mat) [3]f32 {
        const v = zm.f32x4(pos[0], pos[1], pos[2], 1.0);
        const r = zm.mul(v, mtx);
        return .{ r[0], r[1], r[2] };
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 3D primitives
    // ══════════════════════════════════════════════════════════════════════════

    pub fn addCube(self: *GeometryBuilder, opts: CubeOptions) !void {
        const h = opts.size * 0.5;
        const mtx = opts.transform.toMatrix();
        const u = opts.uv_scale;

        // 6 faces × 4 verts, each face has its own UV set
        const faces = [6][4][3]f32{
            // +Z front
            .{ .{ -h, h, h }, .{ h, h, h }, .{ -h, -h, h }, .{ h, -h, h } },
            // -Z back
            .{ .{ h, h, -h }, .{ -h, h, -h }, .{ h, -h, -h }, .{ -h, -h, -h } },
            // +Y top
            .{ .{ -h, h, -h }, .{ h, h, -h }, .{ -h, h, h }, .{ h, h, h } },
            // -Y bottom
            .{ .{ -h, -h, h }, .{ h, -h, h }, .{ -h, -h, -h }, .{ h, -h, -h } },
            // +X right
            .{ .{ h, h, h }, .{ h, h, -h }, .{ h, -h, h }, .{ h, -h, -h } },
            // -X left
            .{ .{ -h, h, -h }, .{ -h, h, h }, .{ -h, -h, -h }, .{ -h, -h, h } },
        };
        const face_uvs = [4][2]f32{ .{ 0, 0 }, .{ u, 0 }, .{ 0, u }, .{ u, u } };

        for (faces) |face| {
            const b = self.base();
            for (face, 0..) |lp, i| {
                try self.pushVertex(.init(
                    applyTransform(lp, mtx),
                    opts.color,
                    face_uvs[i],
                ));
            }
            try self.pushTri(b + 0, b + 1, b + 2);
            try self.pushTri(b + 1, b + 3, b + 2);
        }
    }

    pub fn addSphere(self: *GeometryBuilder, opts: SphereOptions) !void {
        const seg: u32 = @max(3, opts.segments);
        const stk: u32 = @max(2, opts.stacks);
        const r = opts.radius;
        const mtx = opts.transform.toMatrix();
        const b = self.base();

        var s: u32 = 0;
        while (s <= stk) : (s += 1) {
            const phi = std.math.pi * @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(stk));
            var g: u32 = 0;
            while (g <= seg) : (g += 1) {
                const theta = 2.0 * std.math.pi * @as(f32, @floatFromInt(g)) / @as(f32, @floatFromInt(seg));
                const lp = [3]f32{
                    r * @sin(phi) * @cos(theta),
                    r * @cos(phi),
                    r * @sin(phi) * @sin(theta),
                };
                const uv = [2]f32{
                    @as(f32, @floatFromInt(g)) / @as(f32, @floatFromInt(seg)),
                    @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(stk)),
                };
                try self.pushVertex(.init(applyTransform(lp, mtx), opts.color, uv));
            }
        }

        s = 0;
        while (s < stk) : (s += 1) {
            var g: u32 = 0;
            while (g < seg) : (g += 1) {
                const a: u16 = @intCast(b + s * (seg + 1) + g);
                const bc: u16 = @intCast(b + (s + 1) * (seg + 1) + g);
                try self.pushTri(a, bc, a + 1);
                try self.pushTri(a + 1, bc, bc + 1);
            }
        }
    }

    pub fn addCylinder(self: *GeometryBuilder, opts: CylinderOptions) !void {
        const seg: u32 = @max(3, opts.segments);
        const r = opts.radius;
        const h = opts.height * 0.5;
        const mtx = opts.transform.toMatrix();

        // Side
        var i: u32 = 0;
        while (i <= seg) : (i += 1) {
            const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            const u_coord = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            const b = self.base();
            try self.pushVertex(.init(applyTransform(.{ r * @cos(a), h, r * @sin(a) }, mtx), opts.color, .{ u_coord, 0 }));
            try self.pushVertex(.init(applyTransform(.{ r * @cos(a), -h, r * @sin(a) }, mtx), opts.color, .{ u_coord, 1 }));
            if (i > 0) {
                const o = b - 2;
                try self.pushTri(@intCast(o), @intCast(o + 2), @intCast(o + 1));
                try self.pushTri(@intCast(o + 2), @intCast(o + 3), @intCast(o + 1));
            }
        }

        if (opts.caps) {
            // Top cap
            const tc = self.base();
            try self.pushVertex(.init(applyTransform(.{ 0, h, 0 }, mtx), opts.color, .{ 0.5, 0.5 }));
            i = 0;
            while (i < seg) : (i += 1) {
                const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
                try self.pushVertex(.init(applyTransform(.{ r * @cos(a), h, r * @sin(a) }, mtx), opts.color, .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) }));
            }
            i = 0;
            while (i < seg) : (i += 1) {
                try self.pushTri(tc, @intCast(tc + 1 + i), @intCast(tc + 1 + (i + 1) % seg));
            }

            // Bottom cap
            const bc = self.base();
            try self.pushVertex(.init(applyTransform(.{ 0, -h, 0 }, mtx), opts.color, .{ 0.5, 0.5 }));
            i = 0;
            while (i < seg) : (i += 1) {
                const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
                try self.pushVertex(.init(applyTransform(.{ r * @cos(a), -h, r * @sin(a) }, mtx), opts.color, .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) }));
            }
            i = 0;
            while (i < seg) : (i += 1) {
                try self.pushTri(bc, @intCast(bc + 1 + (i + 1) % seg), @intCast(bc + 1 + i));
            }
        }
    }

    pub fn addCone(self: *GeometryBuilder, opts: ConeOptions) !void {
        const seg: u32 = @max(3, opts.segments);
        const r = opts.radius;
        const h = opts.height;
        const mtx = opts.transform.toMatrix();

        // Tip
        const tip_idx = self.base();
        try self.pushVertex(.init(applyTransform(.{ 0, h * 0.5, 0 }, mtx), opts.color, .{ 0.5, 0 }));

        var i: u32 = 0;
        while (i < seg) : (i += 1) {
            const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            const u_coord = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            try self.pushVertex(.init(applyTransform(.{ r * @cos(a), -h * 0.5, r * @sin(a) }, mtx), opts.color, .{ u_coord, 1 }));
        }
        i = 0;
        while (i < seg) : (i += 1) {
            try self.pushTri(tip_idx, @intCast(tip_idx + 1 + i), @intCast(tip_idx + 1 + (i + 1) % seg));
        }

        if (opts.cap) {
            const bc = self.base();
            try self.pushVertex(.init(applyTransform(.{ 0, -h * 0.5, 0 }, mtx), opts.color, .{ 0.5, 0.5 }));
            i = 0;
            while (i < seg) : (i += 1) {
                const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
                try self.pushVertex(.init(applyTransform(.{ r * @cos(a), -h * 0.5, r * @sin(a) }, mtx), opts.color, .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) }));
            }
            i = 0;
            while (i < seg) : (i += 1) {
                try self.pushTri(bc, @intCast(bc + 1 + (i + 1) % seg), @intCast(bc + 1 + i));
            }
        }
    }

    pub fn addTorus(self: *GeometryBuilder, opts: TorusOptions) !void {
        const seg: u32 = @max(4, opts.major_segments);
        const stk: u32 = @max(3, opts.minor_segments);
        const R = opts.major_radius;
        const r = opts.minor_radius;
        const mtx = opts.transform.toMatrix();
        const b = self.base();

        var s: u32 = 0;
        while (s <= seg) : (s += 1) {
            const u_f = @as(f32, @floatFromInt(s)) / @as(f32, @floatFromInt(seg));
            const phi = 2.0 * std.math.pi * u_f;
            var t: u32 = 0;
            while (t <= stk) : (t += 1) {
                const v_f = @as(f32, @floatFromInt(t)) / @as(f32, @floatFromInt(stk));
                const theta = 2.0 * std.math.pi * v_f;
                const lp = [3]f32{
                    (R + r * @cos(theta)) * @cos(phi),
                    r * @sin(theta),
                    (R + r * @cos(theta)) * @sin(phi),
                };
                try self.pushVertex(.init(applyTransform(lp, mtx), opts.color, .{ u_f, v_f }));
            }
        }

        s = 0;
        while (s < seg) : (s += 1) {
            var t: u32 = 0;
            while (t < stk) : (t += 1) {
                const a: u16 = @intCast(b + s * (stk + 1) + t);
                const bc: u16 = @intCast(b + (s + 1) * (stk + 1) + t);
                try self.pushTri(a, bc, a + 1);
                try self.pushTri(a + 1, bc, bc + 1);
            }
        }
    }

    pub fn addPlane(self: *GeometryBuilder, opts: PlaneOptions) !void {
        const sw: u32 = @max(1, opts.subdivide_w);
        const sd: u32 = @max(1, opts.subdivide_d);
        const w = opts.width;
        const d = opts.depth;
        const mtx = opts.transform.toMatrix();
        const b = self.base();

        var iz: u32 = 0;
        while (iz <= sd) : (iz += 1) {
            var ix: u32 = 0;
            while (ix <= sw) : (ix += 1) {
                const fx = @as(f32, @floatFromInt(ix)) / @as(f32, @floatFromInt(sw));
                const fz = @as(f32, @floatFromInt(iz)) / @as(f32, @floatFromInt(sd));
                const lp = [3]f32{ (fx - 0.5) * w, 0, (fz - 0.5) * d };
                try self.pushVertex(.init(applyTransform(lp, mtx), opts.color, .{ fx * opts.uv_scale, fz * opts.uv_scale }));
            }
        }

        iz = 0;
        while (iz < sd) : (iz += 1) {
            var ix: u32 = 0;
            while (ix < sw) : (ix += 1) {
                const a: u16 = @intCast(b + iz * (sw + 1) + ix);
                const bc: u16 = @intCast(b + (iz + 1) * (sw + 1) + ix);
                try self.pushTri(a, bc, a + 1);
                try self.pushTri(a + 1, bc, bc + 1);
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // 2D primitives  (z = 0, screen-space or NDC)
    // ══════════════════════════════════════════════════════════════════════════

    pub fn addRect2D(self: *GeometryBuilder, opts: RectOptions) !void {
        const b = self.base();
        try self.pushVertex(.init(.{ opts.x, opts.y + opts.h, 0 }, opts.color, opts.uv[0]));
        try self.pushVertex(.init(.{ opts.x + opts.w, opts.y + opts.h, 0 }, opts.color, opts.uv[1]));
        try self.pushVertex(.init(.{ opts.x, opts.y, 0 }, opts.color, opts.uv[2]));
        try self.pushVertex(.init(.{ opts.x + opts.w, opts.y, 0 }, opts.color, opts.uv[3]));
        try self.pushTri(b + 0, b + 1, b + 2);
        try self.pushTri(b + 1, b + 3, b + 2);
    }

    /// Textured quad — pass explicit corner positions and UVs.
    pub fn addQuadUV(self: *GeometryBuilder, opts: QuadUVOptions) !void {
        const b = self.base();
        try self.pushVertex(.init(.{ opts.tl[0], opts.tl[1], 0 }, opts.color, opts.uv_tl));
        try self.pushVertex(.init(.{ opts.tr[0], opts.tr[1], 0 }, opts.color, opts.uv_tr));
        try self.pushVertex(.init(.{ opts.bl[0], opts.bl[1], 0 }, opts.color, opts.uv_bl));
        try self.pushVertex(.init(.{ opts.br[0], opts.br[1], 0 }, opts.color, opts.uv_br));
        try self.pushTri(b + 0, b + 1, b + 2);
        try self.pushTri(b + 1, b + 3, b + 2);
    }

    pub fn addCircle2D(self: *GeometryBuilder, opts: CircleOptions) !void {
        const seg: u32 = @max(3, opts.segments);
        const b = self.base();
        // Centre
        try self.pushVertex(.init(.{ opts.cx, opts.cy, 0 }, opts.color, .{ 0.5, 0.5 }));
        var i: u32 = 0;
        while (i < seg) : (i += 1) {
            const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            try self.pushVertex(.init(
                .{ opts.cx + opts.radius * @cos(a), opts.cy + opts.radius * @sin(a), 0 },
                opts.color,
                .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) },
            ));
        }
        i = 0;
        while (i < seg) : (i += 1) {
            try self.pushTri(b, @intCast(b + 1 + i), @intCast(b + 1 + (i + 1) % seg));
        }
    }

    pub fn addRing2D(self: *GeometryBuilder, opts: RingOptions) !void {
        const seg: u32 = @max(3, opts.segments);
        const b = self.base();
        var i: u32 = 0;
        while (i < seg) : (i += 1) {
            const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            const u_coord = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg));
            try self.pushVertex(.init(
                .{ opts.cx + opts.outer_radius * @cos(a), opts.cy + opts.outer_radius * @sin(a), 0 },
                opts.color,
                .{ u_coord, 0 },
            ));
            try self.pushVertex(.init(
                .{ opts.cx + opts.inner_radius * @cos(a), opts.cy + opts.inner_radius * @sin(a), 0 },
                opts.color,
                .{ u_coord, 1 },
            ));
        }
        i = 0;
        while (i < seg) : (i += 1) {
            const o: u16 = @intCast(b + i * 2);
            const n: u16 = @intCast(b + ((i + 1) % seg) * 2);
            try self.pushTri(o, n, o + 1);
            try self.pushTri(n, n + 1, o + 1);
        }
    }

    pub fn addLine2D(self: *GeometryBuilder, opts: LineOptions) !void {
        const dx = opts.x1 - opts.x0;
        const dy = opts.y1 - opts.y0;
        const len = @sqrt(dx * dx + dy * dy);
        if (len < 1e-6) return;
        const nx = -dy / len * opts.thickness * 0.5;
        const ny = dx / len * opts.thickness * 0.5;
        const b = self.base();
        try self.pushVertex(.init(.{ opts.x0 + nx, opts.y0 + ny, 0 }, opts.color, .{ 0, 0 }));
        try self.pushVertex(.init(.{ opts.x0 - nx, opts.y0 - ny, 0 }, opts.color, .{ 0, 1 }));
        try self.pushVertex(.init(.{ opts.x1 + nx, opts.y1 + ny, 0 }, opts.color, .{ 1, 0 }));
        try self.pushVertex(.init(.{ opts.x1 - nx, opts.y1 - ny, 0 }, opts.color, .{ 1, 1 }));
        try self.pushTri(b + 0, b + 2, b + 1);
        try self.pushTri(b + 1, b + 2, b + 3);
    }

    pub fn addNgon2D(self: *GeometryBuilder, opts: NgonOptions) !void {
        const seg: u32 = @max(3, opts.sides);
        const b = self.base();
        try self.pushVertex(.init(.{ opts.cx, opts.cy, 0 }, opts.color, .{ 0.5, 0.5 }));
        var i: u32 = 0;
        while (i < seg) : (i += 1) {
            const a = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(seg)) - std.math.pi * 0.5;
            try self.pushVertex(.init(
                .{ opts.cx + opts.radius * @cos(a), opts.cy + opts.radius * @sin(a), 0 },
                opts.color,
                .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) },
            ));
        }
        i = 0;
        while (i < seg) : (i += 1) {
            try self.pushTri(b, @intCast(b + 1 + i), @intCast(b + 1 + (i + 1) % seg));
        }
    }

    pub fn addStar2D(self: *GeometryBuilder, opts: StarOptions) !void {
        const n: u32 = @max(3, opts.points);
        const pts = n * 2;
        const b = self.base();
        try self.pushVertex(.init(.{ opts.cx, opts.cy, 0 }, opts.color, .{ 0.5, 0.5 }));
        var i: u32 = 0;
        while (i < pts) : (i += 1) {
            const a = std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n)) - std.math.pi * 0.5;
            const r = if (i % 2 == 0) opts.outer_radius else opts.inner_radius;
            try self.pushVertex(.init(
                .{ opts.cx + r * @cos(a), opts.cy + r * @sin(a), 0 },
                opts.color,
                .{ 0.5 + 0.5 * @cos(a), 0.5 + 0.5 * @sin(a) },
            ));
        }
        i = 0;
        while (i < pts) : (i += 1) {
            try self.pushTri(b, @intCast(b + 1 + i), @intCast(b + 1 + (i + 1) % pts));
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Texture helpers
    // ══════════════════════════════════════════════════════════════════════════

    /// Create a 1×1 solid colour texture.
    pub fn createSolidTexture(r: u8, g: u8, b_: u8, a: u8) bgfx.TextureHandle {
        const pixel = [4]u8{ r, g, b_, a };
        const mem = bgfx.copy(&pixel, 4);
        return bgfx.createTexture2D(1, 1, false, 1, .BGRA8, bgfx.TextureFlags_None, mem);
    }

    /// Load a texture from raw RGBA bytes (e.g. from stb_image).
    pub fn createTextureFromRGBA(
        width: u16,
        height: u16,
        data: []const u8,
    ) bgfx.TextureHandle {
        const mem = bgfx.copy(data.ptr, @intCast(data.len));
        return bgfx.createTexture2D(width, height, false, 1, .RGBA8, bgfx.TextureFlags_None, mem);
    }

    /// Create uniform handle for a sampler. Keep alive as long as the program runs.
    pub fn createSamplerUniform(name: [*:0]const u8) bgfx.UniformHandle {
        return bgfx.createUniform(name, .Sampler, 1);
    }
};

// ─── View helpers ─────────────────────────────────────────────────────────────

pub const Views = enum(u8) {
    @"3d" = 0,
    @"2d" = 1,
};

/// Set up the 3D view with perspective projection.
pub fn setup3DView(
    view_id: u8,
    view_mtx: zm.Mat,
    proj_mtx: zm.Mat,
    viewport_w: u32,
    viewport_h: u32,
) void {
    const math = @import("math.zig");
    bgfx.setViewRect(view_id, 0, 0, @intCast(viewport_w), @intCast(viewport_h));
    bgfx.setViewTransform(view_id, &math.matToArr(view_mtx), &math.matToArr(proj_mtx));
}

/// Set up the 2D view with an orthographic projection matching pixel/NDC coords.
/// Pass width=2, height=2 for NDC (-1..1). Pass actual pixel dims for pixel-space.
pub fn setup2DView(
    view_id: u8,
    viewport_w: u32,
    viewport_h: u32,
    orth_w: f32,
    orth_h: f32,
) void {
    const math = @import("math.zig");
    bgfx.setViewRect(view_id, 0, 0, @intCast(viewport_w), @intCast(viewport_h));
    const identity = zm.identity();
    const proj = zm.orthographicRhGl(orth_w, orth_h, -1.0, 1.0);
    bgfx.setViewTransform(view_id, &math.matToArr(identity), &math.matToArr(proj));
}

// ─── State presets ────────────────────────────────────────────────────────────

pub const StatePresets = struct {
    pub const opaque_3d =
        bgfx.StateFlags_WriteRgb |
        bgfx.StateFlags_WriteA |
        bgfx.StateFlags_WriteZ |
        bgfx.StateFlags_DepthTestLess;

    pub const opaque_2d =
        bgfx.StateFlags_WriteRgb |
        bgfx.StateFlags_WriteA;

    pub const alpha_blend_2d =
        bgfx.StateFlags_WriteRgb |
        bgfx.StateFlags_WriteA |
        bgfx.StateFlags_BlendAlpha;

    pub const wireframe =
        bgfx.StateFlags_WriteRgb |
        bgfx.StateFlags_WriteA |
        bgfx.StateFlags_WriteZ |
        bgfx.StateFlags_DepthTestLess |
        bgfx.StateFlags_PtLines;
};
