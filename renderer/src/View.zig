const View = @This();
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");
const ShaderProgram = @import("ShaderProgram.zig");

id: u16,
projection_mtx: math.Mat4,
view_mtx: math.Mat4,
model_mtx: math.Mat4,

pub fn init(id: u16) View {
    return .{
        .id = id,
        .model_mtx = math.Mat4.identity(),
        .projection_mtx = math.Mat4.identity(),
        .view_mtx = math.Mat4.identity(),
    };
}

pub fn setProjectionMtx(self: *View, mtx: math.Mat4) void {
    self.projection_mtx = mtx;
    self.updateViewTransform();
}

pub fn setViewMtx(self: *View, mtx: math.Mat4) void {
    self.view_mtx = mtx;
    self.updateViewTransform();
}

pub fn setModelMtx(self: *View, mtx: math.Mat4) void {
    self.model_mtx = mtx;
}

pub fn touch(self: *const View) void {
    bgfx.touch(self.id);
}

pub fn submit(
    self: *const View,
    program: *const ShaderProgram,
    depth: u32,
) void {
    bgfx.submit(self.id, program.program_handle, depth, bgfx.DiscardFlags_All);
}

inline fn updateViewTransform(self: *View) void {
    bgfx.setViewTransform(self.id, &self.view_mtx.m, &self.projection_mtx.m);
}
