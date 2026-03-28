const Self = @This();
const std = @import("std");
const math = @import("math.zig");
const Color = @import("../components/Color.zig");
const bgfx = @import("bgfx").bgfx;
const Vertex = @import("Vertex.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../assets/Image.zig");
const Mesh = @import("Mesh.zig");
const DynamicMesh = @import("DynamicMesh.zig");

pub const RenderCommand = struct {
    mesh: *Mesh,
    transform: math.Mat,
};

pub const Map = std.AutoArrayHashMap(Id, Self);

pub const Id = enum(u8) {
    @"2d" = 0,
    @"3d" = 1,
    ui = 2,
};

id: Id,
proj_mtx: math.Mat = math.identity(),
view_mtx: math.Mat = math.identity(),
model_mtx: math.Mat = math.identity(),
clear_color: Color = .black,
clear_flags: u16 = bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth,
max_draw_distance: ?f32 = null, // null = unlimited
transient_submissions: std.ArrayList(TransientSubmission) = .empty,
render_commands: std.ArrayList(RenderCommand) = .empty,
dynamic_meshes: std.ArrayList(*DynamicMesh) = .empty,
cam_pos: ?[3]f32 = null, // Similar behaviour to max_draw_distance being null
allocator: std.mem.Allocator,

// Replaced meshes with per-frame render_commands

pub fn addDynamicMesh(self: *Self, mesh: *DynamicMesh) void {
    self.dynamic_meshes.append(self.allocator, mesh) catch unreachable;
}

pub fn removeDynamicMesh(self: *Self, mesh: *DynamicMesh) void {
    for (self.dynamic_meshes.items, 0..) |m, i| {
        if (m == mesh) {
            _ = self.dynamic_meshes.swapRemove(i);
            break;
        }
    }
}

pub fn deinit(self: *Self) void {
    for (self.transient_submissions.items) |sub| {
        self.allocator.free(sub.vertices);
        self.allocator.free(sub.indices);
    }
    self.transient_submissions.deinit(self.allocator);
    self.dynamic_meshes.deinit(self.allocator);
    self.render_commands.deinit(self.allocator);
}

pub const TransientSubmission = struct {
    vertices: []Vertex,
    indices: []u16,
    shader: ?ShaderProgram,
    texture: ?*const Image,
    transform: ?math.Mat,
    blend: bool = false,
};
