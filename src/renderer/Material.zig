const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const ShaderProgram = @import("ShaderProgram.zig");
const Image = @import("../primitive/Image.zig");
const Material = @This();

pub const UniformValue = union(enum) {
    vec4: [4]f32,
    float: f32,
    texture: *const Image,
    vec4_array: struct {
        data: [4][4]f32, // max 4 elements
        count: u32,
    },
};
program: ShaderProgram,
uniforms: std.StringHashMap(UniformValue),
uniform_handles: std.StringHashMap(bgfx.UniformHandle),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, program: ShaderProgram) Material {
    return .{
        .program = program,
        .uniforms = std.StringHashMap(UniformValue).init(allocator),
        .uniform_handles = std.StringHashMap(bgfx.UniformHandle).init(allocator),
        .allocator = allocator,
    };
}
pub fn setVec4Array(self: *Material, name: []const u8, values: [][4]f32, count: u32) void {
    if (!self.uniform_handles.contains(name)) {
        const handle = bgfx.createUniform(@ptrCast(name.ptr), .Vec4, 4);
        self.uniform_handles.put(name, handle) catch unreachable;
    }
    var data: [4][4]f32 = std.mem.zeroes([4][4]f32);
    for (0..@min(count, 4)) |i| {
        data[i] = values[i];
    }
    self.uniforms.put(name, .{ .vec4_array = .{ .data = data, .count = count } }) catch unreachable;
}
pub fn setVec4(self: *Material, name: []const u8, value: [4]f32) void {
    self.uniforms.put(name, .{ .vec4 = value }) catch unreachable;
    if (!self.uniform_handles.contains(name)) {
        const handle = bgfx.createUniform(@ptrCast(name.ptr), .Vec4, 1);
        self.uniform_handles.put(name, handle) catch unreachable;
    }
}

pub fn setFloat(self: *Material, name: []const u8, value: f32) void {
    self.uniforms.put(name, .{ .float = value }) catch unreachable;
    if (!self.uniform_handles.contains(name)) {
        const handle = bgfx.createUniform(@ptrCast(name.ptr), .Vec4, 1);
        self.uniform_handles.put(name, handle) catch unreachable;
    }
}

pub fn setTexture(self: *Material, name: []const u8, image: *const Image) void {
    self.uniforms.put(name, .{ .texture = image }) catch unreachable;
    if (!self.uniform_handles.contains(name)) {
        const handle = bgfx.createUniform(@ptrCast(name.ptr), .Sampler, 1);
        self.uniform_handles.put(name, handle) catch unreachable;
    }
}

pub fn bind(self: *const Material, tex_uniform: bgfx.UniformHandle, white_texture: *const Image) void {
    var iter = self.uniforms.iterator();
    var texture_slot: u8 = 0;
    while (iter.next()) |entry| {
        const handle = self.uniform_handles.get(entry.key_ptr.*) orelse continue;
        switch (entry.value_ptr.*) {
            .vec4 => |v| bgfx.setUniform(handle, &v, 1),
            .float => |f| {
                const v: [4]f32 = .{ f, 0.0, 0.0, 0.0 };
                bgfx.setUniform(handle, &v, 1);
            },
            .texture => |img| {
                bgfx.setTexture(texture_slot, handle, img.handle, std.math.maxInt(u32));
                texture_slot += 1;
            },
            .vec4_array => |arr| {
                bgfx.setUniform(handle, &arr.data, @intCast(arr.count));
            },
        }
    }
    // if no texture was set use white fallback on slot 0
    if (texture_slot == 0) {
        bgfx.setTexture(0, tex_uniform, white_texture.handle, std.math.maxInt(u32));
    }
}
pub fn bindWithoutTexture(self: *const Material) void {
    // if (self.uniforms.count() == 0) {
    //     return;
    // }
    var iter = self.uniforms.iterator();
    while (iter.next()) |entry| {
        const handle = self.uniform_handles.get(entry.key_ptr.*) orelse continue;
        switch (entry.value_ptr.*) {
            .vec4 => |v| bgfx.setUniform(handle, &v, 1),
            .float => |f| {
                const v: [4]f32 = .{ f, 0.0, 0.0, 0.0 };
                bgfx.setUniform(handle, &v, 1);
            },
            .vec4_array => |arr| bgfx.setUniform(handle, &arr.data, @intCast(arr.count)),
            .texture => {}, // skip
        }
    }
}
pub fn deinit(self: *Material) void {
    var it = self.uniform_handles.valueIterator();
    while (it.next()) |handle| {
        bgfx.destroyUniform(handle.*);
    }
    self.uniforms.deinit();
    self.uniform_handles.deinit();
    self.program.deinit();
}
