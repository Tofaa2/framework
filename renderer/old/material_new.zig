/// Material system - binds shaders and textures to draw calls
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const resources = @import("resources_new.zig");

pub const TextureSlot = struct {
    slot: u8,
    texture: resources.TextureHandle,
    name: []const u8,
    uniform_handle: bgfx.UniformHandle,
};

pub const UniformValue = union(enum) {
    vec4: [4]f32,
    vec3: [3]f32,
    float: f32,
    sampler: resources.TextureHandle,
};

pub const MaterialUniform = struct {
    name: []const u8,
    value: UniformValue,
    uniform_handle: bgfx.UniformHandle,
};

pub const Material = struct {
    program: resources.ProgramHandle,
    state: u64,
    allocator: std.mem.Allocator,
    textures: std.ArrayListUnmanaged(TextureSlot),
    uniforms: std.ArrayListUnmanaged(MaterialUniform),

    pub fn init(program: resources.ProgramHandle, allocator: std.mem.Allocator) Material {
        return .{
            .program = program,
            .state = bgfx.StateFlags_WriteRgb |
                bgfx.StateFlags_WriteA |
                bgfx.StateFlags_WriteZ |
                bgfx.StateFlags_DepthTestLess,
            .allocator = allocator,
            .textures = .{},
            .uniforms = .{},
        };
    }

    pub fn deinit(self: *Material, res: *resources.ResourcePool) void {
        _ = res;
        for (self.textures.items) |tex| {
            bgfx.destroyUniform(tex.uniform_handle);
            self.allocator.free(tex.name);
        }
        for (self.uniforms.items) |uni| {
            bgfx.destroyUniform(uni.uniform_handle);
            self.allocator.free(uni.name);
        }
        self.textures.deinit(self.allocator);
        self.uniforms.deinit(self.allocator);
    }

    pub fn setTexture(self: *Material, slot: u8, texture: resources.TextureHandle, name: []const u8) !void {
        const uniform = bgfx.createUniform(name.ptr, .Sampler, 1);
        try self.textures.append(self.allocator, .{
            .slot = slot,
            .texture = texture,
            .name = try self.allocator.dupe(u8, name),
            .uniform_handle = uniform,
        });
    }

    pub fn setVec4(self: *Material, name: []const u8, v: [4]f32) !void {
        for (self.uniforms.items) |*uni| {
            if (std.mem.eql(u8, uni.name, name)) {
                uni.value = .{ .vec4 = v };
                return;
            }
        }
        const uniform = bgfx.createUniform(name.ptr, .Vec4, 1);
        try self.uniforms.append(self.allocator, .{
            .name = try self.allocator.dupe(u8, name),
            .value = .{ .vec4 = v },
            .uniform_handle = uniform,
        });
    }

    pub fn setVec3(self: *Material, name: []const u8, v: [3]f32) !void {
        for (self.uniforms.items) |*uni| {
            if (std.mem.eql(u8, uni.name, name)) {
                uni.value = .{ .vec3 = v };
                return;
            }
        }
        const uniform = bgfx.createUniform(name.ptr, .Vec3, 1);
        try self.uniforms.append(self.allocator, .{
            .name = try self.allocator.dupe(u8, name),
            .value = .{ .vec3 = v },
            .uniform_handle = uniform,
        });
    }

    pub fn setFloat(self: *Material, name: []const u8, v: f32) !void {
        for (self.uniforms.items) |*uni| {
            if (std.mem.eql(u8, uni.name, name)) {
                uni.value = .{ .float = v };
                return;
            }
        }
        const uniform = bgfx.createUniform(name.ptr, .Vec4, 1);
        try self.uniforms.append(self.allocator, .{
            .name = try self.allocator.dupe(u8, name),
            .value = .{ .float = v },
            .uniform_handle = uniform,
        });
    }

    pub fn bind(self: *const Material, res: *const resources.ResourcePool) void {
        _ = res.getProgram(self.program) orelse return;
        _ = bgfx.setState(self.state, 0);

        for (self.textures.items) |tex_slot| {
            const tex = res.getTexture(tex_slot.texture);
            if (tex) |t| {
                _ = bgfx.setTexture(tex_slot.slot, tex_slot.uniform_handle, t.handle, bgfx.TextureFlags_None);
            }
        }

        for (self.uniforms.items) |uni| {
            switch (uni.value) {
                .vec4 => |v| _ = bgfx.setUniform(uni.uniform_handle, &v, 1),
                .vec3 => |v| _ = bgfx.setUniform(uni.uniform_handle, &v, 1),
                .float => |v| {
                    const arr = [4]f32{ v, 0, 0, 0 };
                    _ = bgfx.setUniform(uni.uniform_handle, &arr, 1);
                },
                .sampler => {},
            }
        }
    }
};
