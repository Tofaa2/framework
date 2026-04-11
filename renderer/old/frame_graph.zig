/// frame_graph.zig
/// Mid-level frame graph. Declares named passes; each pass collects DrawCalls
/// which are sorted and submitted in order by the renderer.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const resources = @import("resources.zig");
const material = @import("material.zig");
const sort_key = @import("sort_key.zig");
const math = @import("math.zig");

// ─────────────────────────────────────────────────────────────
// Draw call — everything needed to issue one bgfx draw
// ─────────────────────────────────────────────────────────────

pub const DrawCall = struct {
    sort_key: u64 = 0,
    view_id: u8 = 0,
    material: resources.MaterialHandle = .invalid,
    mesh: resources.MeshHandle = .invalid,
    transform: [16]f32 = identity4x4,
    depth: u32 = 0,
    /// Optional: override state from material
    state_override: ?u64 = null,
};

const identity4x4 = [16]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
};

// ─────────────────────────────────────────────────────────────
// Transient draw — dynamic geometry (UI, particles, debug)
// ─────────────────────────────────────────────────────────────

pub const TransientDraw = struct {
    sort_key: u64 = 0,
    view_id: u8 = 0,
    material: resources.MaterialHandle = .invalid,
    vertices: []const u8, // raw bytes, caller manages lifetime until flush
    indices: []const u16,
    vertex_count: u32,
    transform: [16]f32 = identity4x4,
    state: u64 = bgfx.StateFlags_WriteRgb |
        bgfx.StateFlags_WriteA |
        bgfx.StateFlags_WriteZ |
        bgfx.StateFlags_DepthTestLess,
};

// ─────────────────────────────────────────────────────────────
// Clear config
// ─────────────────────────────────────────────────────────────

pub const ClearConfig = struct {
    flags: u16 = bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth,
    rgba: u32 = 0x000000FF,
    depth: f32 = 1.0,
    stencil: u8 = 0,
};

// ─────────────────────────────────────────────────────────────
// Camera — view + projection matrices for a pass
// ─────────────────────────────────────────────────────────────

pub const Camera = struct {
    view: [16]f32 = identity4x4,
    proj: [16]f32 = identity4x4,
};

// ─────────────────────────────────────────────────────────────
// RenderPass
// ─────────────────────────────────────────────────────────────

pub const RenderPass = struct {
    name: []const u8,
    view_id: u8,
    clear: ClearConfig = .{},
    camera: Camera = .{},
    viewport: struct { x: u16, y: u16, w: u16, h: u16 } = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
    enabled: bool = true,

    draws: std.ArrayListUnmanaged(DrawCall) = .{},
    transient_draws: std.ArrayListUnmanaged(TransientDraw) = .{},
    sort_pairs: std.ArrayListUnmanaged(sort_key.DrawPair) = .{},

    pub fn deinit(self: *RenderPass, allocator: std.mem.Allocator) void {
        self.draws.deinit(allocator);
        self.transient_draws.deinit(allocator);
        self.sort_pairs.deinit(allocator);
    }

    pub fn addDraw(self: *RenderPass, allocator: std.mem.Allocator, dc: DrawCall) !void {
        try self.draws.append(allocator, dc);
    }

    pub fn addTransient(self: *RenderPass, allocator: std.mem.Allocator, td: TransientDraw) !void {
        try self.transient_draws.append(allocator, td);
    }

    pub fn clear_draws(self: *RenderPass) void {
        self.draws.clearRetainingCapacity();
        self.transient_draws.clearRetainingCapacity();
        self.sort_pairs.clearRetainingCapacity();
    }
};

// ─────────────────────────────────────────────────────────────
// FrameGraph
// ─────────────────────────────────────────────────────────────

pub const FrameGraph = struct {
    passes: std.ArrayListUnmanaged(RenderPass) = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FrameGraph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FrameGraph) void {
        for (self.passes.items) |*p| p.deinit(self.allocator);
        self.passes.deinit(self.allocator);
    }

    /// Register a pass. Returns a pointer valid until the next addPass call.
    pub fn addPass(self: *FrameGraph, pass: RenderPass) !*RenderPass {
        try self.passes.append(self.allocator, pass);
        return &self.passes.items[self.passes.items.len - 1];
    }

    pub fn getPass(self: *FrameGraph, view_id: u8) ?*RenderPass {
        for (self.passes.items) |*p| {
            if (p.view_id == view_id) return p;
        }
        return null;
    }

    /// Clear all draw calls for next frame. Passes (metadata) are retained.
    pub fn beginFrame(self: *FrameGraph) void {
        for (self.passes.items) |*p| p.clear_draws();
    }

    /// Sort all draw calls within each pass.
    pub fn sort(self: *FrameGraph) !void {
        for (self.passes.items) |*pass| {
            pass.sort_pairs.clearRetainingCapacity();
            for (pass.draws.items, 0..) |dc, i| {
                try pass.sort_pairs.append(self.allocator, .{
                    .key = dc.sort_key,
                    .index = @intCast(i),
                });
            }
            sort_key.sortDrawCalls(pass.sort_pairs.items);
        }
    }
};
