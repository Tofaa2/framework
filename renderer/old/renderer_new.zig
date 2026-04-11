/// Main renderer - orchestrates resources, materials, and drawing
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const core = @import("core.zig");
const resources = @import("resources_new.zig");
const material = @import("material_new.zig");

pub const DrawCall = struct {
    mesh: resources.MeshHandle,
    material: material.Material,
    transform: core.Mat4,
    view_id: u8 = 1,
};

pub const Camera = struct {
    eye: core.Vec3,
    target: core.Vec3,
    up: core.Vec3,
    fov: f32,
    aspect: f32,
    near: f32,
    far: f32,

    pub fn view(self: Camera) core.Mat4 {
        return core.Mat4.lookAt(self.eye, self.target, self.up);
    }

    pub fn projection(self: Camera) core.Mat4 {
        return core.Mat4.perspective(self.fov, self.aspect, self.near, self.far);
    }
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    res: resources.ResourcePool,
    vertex_layout: bgfx.VertexLayout,
    default_texture: resources.TextureHandle,
    width: u32,
    height: u32,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, nwh: ?*anyopaque) !Renderer {
        var bgfx_init = std.mem.zeroes(bgfx.Init);
        bgfx.initCtor(&bgfx_init);
        bgfx_init.platformData.nwh = nwh;
        bgfx_init.resolution.width = width;
        bgfx_init.resolution.height = height;
        bgfx_init.resolution.reset = bgfx.ResetFlags_Vsync;
        bgfx_init.callback = &@import("bgfx_util.zig").bgfx_clbs;
        _ = bgfx.renderFrame(-1);

        if (!bgfx.init(&bgfx_init)) {
            return error.BgfxInitFailed;
        }

        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(bgfx.getRendererType());
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.Color0, 4, .Uint8, true, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        _ = layout.add(.Normal, 3, .Float, false, false);
        _ = layout.add(.Tangent, 4, .Float, false, false);
        layout.end();

        var res = resources.ResourcePool.init(allocator);
        const default_texture = try res.createCheckerboardTexture(32);

        return .{
            .allocator = allocator,
            .res = res,
            .vertex_layout = layout,
            .default_texture = default_texture,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.res.deinit();
        bgfx.shutdown();
    }

    pub fn beginFrame(self: *Renderer) void {
        _ = self;
    }

    pub fn endFrame(self: *Renderer) void {
        _ = self;
        _ = bgfx.frame(0);
    }

    pub fn setViewCamera(self: *Renderer, view_id: u8, cam: Camera) void {
        var view_arr: [16]f32 = undefined;
        var proj_arr: [16]f32 = undefined;
        @memcpy(&view_arr, &cam.view().data);
        @memcpy(&proj_arr, &cam.projection().data);
        bgfx.setViewRect(view_id, 0, 0, @as(u16, @truncate(self.width)), @as(u16, @truncate(self.height)));
        bgfx.setViewClear(view_id, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x333333FF, 1.0, 0);
        bgfx.setViewTransform(view_id, &view_arr, &proj_arr);
    }

    pub fn draw(self: *Renderer, call: DrawCall) void {
        const mesh = self.res.getMesh(call.mesh) orelse return;
        const prog = self.res.getProgram(call.material.program) orelse return;

        var transform_arr: [16]f32 = undefined;
        @memcpy(&transform_arr, &call.transform.data);
        _ = bgfx.setTransform(&transform_arr, 1);
        bgfx.setVertexBuffer(0, mesh.vbh, 0, mesh.vertex_count);
        bgfx.setIndexBuffer(mesh.ibh, 0, mesh.index_count);
        call.material.bind(&self.res);
        bgfx.setState(call.material.state, 0);
        _ = bgfx.submit(call.view_id, prog.handle, 0, bgfx.DiscardFlags_All);
    }

    pub fn createMesh(self: *Renderer, vertices: []const core.Vertex, indices: []const u16) !resources.MeshHandle {
        return self.res.createMesh(&self.vertex_layout, vertices, indices);
    }

    pub fn createPostQuad(self: *Renderer) !resources.MeshHandle {
        return self.res.createPostQuad();
    }

    pub fn createTexture(self: *Renderer, width: u16, height: u16, data: []const u8) !resources.TextureHandle {
        return self.res.createTexture2D(width, height, data);
    }

    pub fn createShaderFromMemory(self: *Renderer, vs_data: []const u8, fs_data: []const u8) !resources.ProgramHandle {
        const vs = try self.res.createShader(vs_data);
        const fs = try self.res.createShader(fs_data);
        return self.res.createProgram(vs, fs);
    }

    pub fn createFramebuffer(self: *Renderer, width: u16, height: u16, has_depth: bool) !resources.FramebufferHandle {
        return self.res.createFramebufferSimple(width, height, has_depth);
    }

    pub fn setViewFramebuffer(self: *Renderer, view_id: u8, fb: resources.FramebufferHandle) void {
        const framebuffer = self.res.getFramebuffer(fb) orelse return;
        bgfx.setViewFrameBuffer(view_id, framebuffer.handle);
        bgfx.setViewRect(view_id, 0, 0, framebuffer.width, framebuffer.height);
        bgfx.setViewClear(view_id, bgfx.ClearFlags_Color, 0x000000FF, 1.0, 0);
    }

    pub fn setViewScreen(self: *Renderer, view_id: u8) void {
        bgfx.setViewFrameBuffer(view_id, bgfx.FrameBufferHandle{ .idx = 0xFFFF });
        bgfx.setViewRect(view_id, 0, 0, @as(u16, @truncate(self.width)), @as(u16, @truncate(self.height)));
        bgfx.setViewClear(view_id, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030FF, 1.0, 0);
    }

    pub fn getFramebufferTexture(self: *Renderer, fb: resources.FramebufferHandle, attachment: u8) resources.TextureHandle {
        return self.res.getFramebufferTexture(fb, attachment);
    }
};

/// Shape generation utilities
pub const Shape = struct {
    pub fn cube() struct { vertices: []core.Vertex, indices: []u16 } {
        const positions = [_][3]f32{
            .{ -1, -1, -1 }, .{ 1, -1, -1 }, .{ 1, 1, -1 }, .{ -1, 1, -1 },
            .{ -1, -1, 1 },  .{ 1, -1, 1 },  .{ 1, 1, 1 },  .{ -1, 1, 1 },
        };
        const normals = [_][3]f32{
            .{ 0, 0, -1 }, .{ 0, 0, 1 }, .{ 0, 1, 0 },
            .{ 0, -1, 0 }, .{ 1, 0, 0 }, .{ -1, 0, 0 },
        };
        const uvs = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 } };

        const faces = [_][4]u8{
            .{ 0, 3, 2, 1 }, // front
            .{ 5, 6, 7, 4 }, // back
            .{ 3, 7, 6, 2 }, // top
            .{ 1, 2, 6, 5 }, // right
            .{ 4, 7, 3, 0 }, // left
            .{ 4, 0, 1, 5 }, // bottom
        };

        var vertices: [24]core.Vertex = undefined;
        var indices: [36]u16 = undefined;

        for (faces, 0..) |face, fi| {
            const n = normals[fi];
            for (0..4) |vi| {
                const vi_idx = fi * 4 + vi;
                vertices[vi_idx] = .{
                    .position = positions[face[vi]],
                    .color = 0xFFFFFFFF,
                    .uv = uvs[vi],
                    .normal = n,
                    .tangent = .{ 1, 0, 0, 1 },
                };
            }
            const idx = fi * 6;
            indices[idx + 0] = @intCast(fi * 4 + 0);
            indices[idx + 1] = @intCast(fi * 4 + 1);
            indices[idx + 2] = @intCast(fi * 4 + 2);
            indices[idx + 3] = @intCast(fi * 4 + 0);
            indices[idx + 4] = @intCast(fi * 4 + 2);
            indices[idx + 5] = @intCast(fi * 4 + 3);
        }

        return .{
            .vertices = &vertices,
            .indices = &indices,
        };
    }

    pub fn quad() struct { vertices: [4]core.Vertex, indices: [6]u16 } {
        return .{
            .vertices = .{
                .{
                    .position = .{ -1, -1, 0 },
                    .color = 0xFFFFFFFF,
                    .uv = .{ 0, 0 },
                    .normal = .{ 0, 0, 1 },
                    .tangent = .{ 1, 0, 0, 1 },
                },
                .{
                    .position = .{ 1, -1, 0 },
                    .color = 0xFFFFFFFF,
                    .uv = .{ 1, 0 },
                    .normal = .{ 0, 0, 1 },
                    .tangent = .{ 1, 0, 0, 1 },
                },
                .{
                    .position = .{ 1, 1, 0 },
                    .color = 0xFFFFFFFF,
                    .uv = .{ 1, 1 },
                    .normal = .{ 0, 0, 1 },
                    .tangent = .{ 1, 0, 0, 1 },
                },
                .{
                    .position = .{ -1, 1, 0 },
                    .color = 0xFFFFFFFF,
                    .uv = .{ 0, 1 },
                    .normal = .{ 0, 0, 1 },
                    .tangent = .{ 1, 0, 0, 1 },
                },
            },
            .indices = .{ 0, 1, 2, 0, 2, 3 },
        };
    }

    pub fn sphere(segments: u32) struct { vertices: []core.Vertex, indices: []u16 } {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const alloc = arena.allocator();
        var vertices = std.ArrayList(core.Vertex).init(alloc);
        var indices = std.ArrayList(u16).init(alloc);

        for (0..segments + 1) |lat| {
            const theta = @as(f32, @floatFromInt(lat)) / @as(f32, @floatFromInt(segments)) * std.math.pi;
            const sin_theta = @sin(theta);
            const cos_theta = @cos(theta);

            for (0..segments + 1) |lon| {
                const phi = @as(f32, @floatFromInt(lon)) / @as(f32, @floatFromInt(segments)) * 2 * std.math.pi;
                const sin_phi = @sin(phi);
                const cos_phi = @cos(phi);

                const x = cos_phi * sin_theta;
                const y = cos_theta;
                const z = sin_phi * sin_theta;

                vertices.append(.{
                    .position = .{ x, y, z },
                    .color = 0xFFFFFFFF,
                    .uv = .{
                        @as(f32, @floatFromInt(lon)) / @as(f32, @floatFromInt(segments)),
                        @as(f32, @floatFromInt(lat)) / @as(f32, @floatFromInt(segments)),
                    },
                    .normal = .{ x, y, z },
                    .tangent = .{ -sin_phi, 0, cos_phi, 1 },
                }) catch unreachable;
            }
        }

        for (0..segments) |lat| {
            for (0..segments) |lon| {
                const first: u16 = @intCast(lat * (segments + 1) + lon);
                const second: u16 = first + segments + 1;

                indices.append(first) catch unreachable;
                indices.append(second) catch unreachable;
                indices.append(first + 1) catch unreachable;

                indices.append(second) catch unreachable;
                indices.append(second + 1) catch unreachable;
                indices.append(first + 1) catch unreachable;
            }
        }

        return .{
            .vertices = vertices.toOwnedSlice() catch unreachable,
            .indices = indices.toOwnedSlice() catch unreachable,
        };
    }
};
