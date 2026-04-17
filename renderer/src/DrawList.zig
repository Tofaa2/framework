/// Per-frame draw command list for 3D geometry.
/// Commands are accumulated during the frame and flushed by RenderWorld.endFrame().
/// Uses the frame allocator — no cleanup required; automatically reset each tick.
const std = @import("std");
const math = @import("math");
const Mesh = @import("Mesh.zig");
const Material = @import("Material.zig");
const DrawList = @This();

pub const MeshDraw = struct {
    mesh: *const Mesh,
    material: Material,
    transform: math.Mat4,
    /// Pre-computed squared distance from the camera (for sorting).
    depth_sq: f32 = 0,
};

commands: std.ArrayListUnmanaged(MeshDraw),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) DrawList {
    return .{
        .commands = .{},
        .allocator = allocator,
    };
}

pub fn deinit(self: *DrawList) void {
    self.commands.deinit(self.allocator);
}

/// Push a mesh draw command. The mesh pointer must remain valid until endFrame().
pub fn push(self: *DrawList, mesh: *const Mesh, material: Material, transform: math.Mat4) void {
    self.commands.append(self.allocator, .{
        .mesh = mesh,
        .material = material,
        .transform = transform,
    }) catch @panic("DrawList OOM");
}

/// Sort opaque draws front-to-back by depth (minimise overdraw).
/// Call with the camera position before flushing.
pub fn sortOpaque(self: *DrawList, camera_pos: math.Vec3) void {
    for (self.commands.items) |*cmd| {
        const t = cmd.transform.getTranslation();
        cmd.depth_sq = math.Vec3.distanceSq(camera_pos, t);
    }
    std.mem.sort(MeshDraw, self.commands.items, {}, struct {
        fn lt(_: void, a: MeshDraw, b: MeshDraw) bool {
            return a.depth_sq < b.depth_sq;
        }
    }.lt);
}

/// Clear all commands. Call at the start of each frame.
pub fn clear(self: *DrawList) void {
    self.commands.clearRetainingCapacity();
}

pub fn len(self: *const DrawList) usize {
    return self.commands.items.len;
}
