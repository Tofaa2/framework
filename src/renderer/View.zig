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

transient_submissions: std.ArrayList(TransientSubmission) = .empty,
meshes: std.ArrayList(*Mesh) = .empty,
dynamic_meshes: std.ArrayList(*DynamicMesh) = .empty,

allocator: std.mem.Allocator,

pub fn addMesh(self: *Self, mesh: *Mesh) void {
    self.meshes.append(self.allocator, mesh) catch unreachable;
}

pub fn addDynamicMesh(self: *Self, mesh: *DynamicMesh) void {
    self.dynamic_meshes.append(self.allocator, mesh) catch unreachable;
}

pub fn deinit(self: *Self) void {
    for (self.transient_submissions.items) |sub| {
        self.allocator.free(sub.vertices);
        self.allocator.free(sub.indices);
    }
    self.transient_submissions.deinit(self.allocator);
    self.dynamic_meshes.deinit(self.allocator);
    self.meshes.deinit(self.allocator);
}

pub const TransientSubmission = struct {
    vertices: []Vertex,
    indices: []u16,
    shader: ?ShaderProgram,
    texture: ?*const Image,
    transform: ?math.Mat,
    blend: bool = false,
};
