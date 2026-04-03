const std = @import("std");
pub const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;
const shaders = @import("shader_module");
pub const math = @import("math.zig");
const zm = math;
var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};
const builtin = @import("builtin");

pub const Viewport = @import("Viewport.zig");
pub const Image = @import("../assets/Image.zig");
pub const ShaderProgram = @import("ShaderProgram.zig");
pub const log = std.log.scoped(.renderer);
const isValid = @import("bgfx_util.zig").isValid;
pub const Color = @import("../components/Color.zig");
pub const View = @import("View.zig");
pub const Vertex = @import("Vertex.zig");
pub const MeshBuilder = @import("MeshBuilder.zig");
pub const Mesh = @import("Mesh.zig");
pub const DynamicMesh = @import("DynamicMesh.zig");
pub const ObjLoader = @import("ObjLoader.zig");
pub const Material = @import("../assets/Material.zig");
pub const Frustum = @import("Frustum.zig");

pub const BuiltinMaterial = enum {
    unlit,
    diffuse,
    skybox,
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    viewport: Viewport,
    unlit_program: ShaderProgram,
    tex_uniform: bgfx.UniformHandle,
    materials: std.EnumMap(BuiltinMaterial, Material),
    white_texture: Image,
    vertex_layout: bgfx.VertexLayout,
    views: View.Map,

    pub fn getView(self: *Renderer, id: View.Id) ?*View {
        return self.views.getPtr(id);
    }

    pub fn getMaterial(self: *Renderer, mat: BuiltinMaterial) *Material {
        return self.materials.getPtr(mat).?;
    }

    pub fn init(
        self: *Renderer,
        allocator: std.mem.Allocator,
        viewport: Viewport,
        window_ptr: ?*anyopaque,
        display_ptr: ?*anyopaque,
    ) !void {
        var bgfx_init = std.mem.zeroes(bgfx.Init);
        bgfx.initCtor(&bgfx_init);

        bgfx_init.platformData.nwh = window_ptr;
        bgfx_init.platformData.ndt = display_ptr;
        bgfx_init.type = .Count;
        bgfx_init.resolution.width = viewport.width;
        bgfx_init.resolution.height = viewport.height;
        bgfx_init.debug = builtin.mode == .Debug;
        bgfx_init.callback = &bgfx_clbs;

        if (!bgfx.init(&bgfx_init)) {
            return error.InitFailed;
        }

        bgfx.setDebug(bgfx.DebugFlags_Stats);

        const tex_uniform = bgfx.createUniform("s_texColor", .Sampler, 1);
        const backend = bgfx.getRendererType();

        const unlit_program = try ShaderProgram.initFromMem(
            shaders.vs_basic.getShaderForRenderer(backend),
            shaders.fs_basic.getShaderForRenderer(backend),
        );
        const diffuse_program = try ShaderProgram.initFromMem(
            shaders.vs_diffuse.getShaderForRenderer(backend),
            shaders.fs_diffuse.getShaderForRenderer(backend),
        );

        const skybox_program = try ShaderProgram.initFromMem(
            shaders.vs_skybox.getShaderForRenderer(backend),
            shaders.fs_skybox.getShaderForRenderer(backend),
        );

        var materials = std.EnumMap(BuiltinMaterial, Material){};
        const unlit = Material.init(allocator, unlit_program);
        const diffuse = Material.init(allocator, diffuse_program);
        const skybox_mat = Material.init(allocator, skybox_program);
        materials.put(.unlit, unlit);
        materials.put(.diffuse, diffuse);
        materials.put(.skybox, skybox_mat);

        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(backend);
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.Color0, 4, .Uint8, true, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        _ = layout.add(.Normal, 3, .Float, false, false);
        layout.end();
        var views = View.Map.init(allocator);

        views.put(.@"2d", .{
            .proj_mtx = math.orthographicOffCenterRhGl(
                0.0,
                @floatFromInt(viewport.width),
                0.0,
                @floatFromInt(viewport.height),
                -1.0,
                1.0,
            ),
            .clear_flags = bgfx.ClearFlags_Depth,
            .id = .@"2d",
            .allocator = allocator,
        }) catch unreachable;
        views.put(.@"3d", .{
            .clear_flags = bgfx.ClearFlags_Depth,
            .proj_mtx = zm.perspectiveFovRhGl(
                0.25 * std.math.pi,
                @as(f32, @floatFromInt(viewport.width)) / @as(f32, @floatFromInt(viewport.height)),
                0.1,
                100.0,
            ),
            .view_mtx = zm.lookAtRh(
                zm.f32x4(0.0, 0.0, -10.0, 1.0),
                zm.f32x4(0.0, 0.0, 0.0, 1.0),
                zm.f32x4(0.0, 1.0, 0.0, 0.0),
            ),
            .id = .@"3d",
            .allocator = allocator,
        }) catch unreachable;
        views.put(.ui, .{
            .proj_mtx = math.orthographicOffCenterRhGl(
                0.0,
                @floatFromInt(viewport.width),
                @floatFromInt(viewport.height),
                0.0,
                -1.0,
                1.0,
            ),
            .clear_flags = bgfx.ClearFlags_None,
            .id = .ui,
            .allocator = allocator,
        }) catch unreachable;

        views.put(.skybox, .{
            .proj_mtx = math.orthographicOffCenterRhGl(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0),
            .clear_flags = bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth,
            .clear_color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
            .id = .skybox,
            .allocator = allocator,
        }) catch unreachable;

        self.allocator = allocator;
        self.viewport = viewport;
        self.unlit_program = unlit_program;
        self.white_texture = Image.initSingleColor(.white);
        self.vertex_layout = layout;
        self.views = views;
        self.tex_uniform = tex_uniform;
        self.materials = materials;
    }

    pub fn resize(self: *Renderer, width: u32, height: u32) void {
        self.viewport.width = width;
        self.viewport.height = height;

        bgfx.reset(width, height, bgfx.ResetFlags_None, bgfx.TextureFormat.Count);
        if (self.views.getPtr(.@"2d")) |v| {
            v.proj_mtx = math.orthographicOffCenterRhGl(
                0.0,
                @floatFromInt(width),
                0.0,
                @floatFromInt(height),
                -1.0,
                1.0,
            );
        }

        if (self.views.getPtr(.@"3d")) |v| {
            v.proj_mtx = zm.perspectiveFovRhGl(
                0.25 * std.math.pi,
                @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
                0.1,
                100.0,
            );
        }
        if (self.views.getPtr(.ui)) |v| {
            v.proj_mtx = math.orthographicOffCenterRhGl(
                0.0,
                @floatFromInt(width),
                @floatFromInt(height),
                0.0,
                -1.0,
                1.0,
            );
        }
    }
    pub fn draw(self: *Renderer, assets: *@import("../core/AssetPool.zig")) void {
        // setup pass - in ID order
        inline for (std.meta.fields(View.Id)) |field| {
            const id: View.Id = @enumFromInt(field.value);
            if (self.views.getPtr(id)) |view| {
                const view_id: u8 = @intFromEnum(view.id);
                bgfx.setViewClear(view_id, view.clear_flags, view.clear_color.toRGBA(), 1.0, 0.0);
                bgfx.setViewRect(view_id, 0, 0, @intCast(self.viewport.width), @intCast(self.viewport.height));
                bgfx.setViewTransform(view_id, &math.matToArr(view.view_mtx), &math.matToArr(view.proj_mtx));
                bgfx.touch(view_id);
            }
        }
        // draw pass - in ID order
        inline for (std.meta.fields(View.Id)) |field| {
            const id: View.Id = @enumFromInt(field.value);
            if (self.views.getPtr(id)) |view| {
                self.drawView(view, assets);
            }
        }
        _ = bgfx.frame(bgfx.FrameFlags_None);
    }

    fn drawView(self: *Renderer, view: *View, assets: *@import("../core/AssetPool.zig")) void {
        const view_id: u8 = @intFromEnum(view.id);
        const vp = zm.mul(view.view_mtx, view.proj_mtx);
        const frustum = Frustum.fromViewProj(vp);
        for (view.render_commands.items) |cmd| {
            const mesh = cmd.mesh;
            const world_center = if (mesh.transform) |t| blk: {
                const c = mesh.bounding_center;
                const wc = zm.mul(zm.f32x4(c[0], c[1], c[2], 1.0), t);
                break :blk [3]f32{ wc[0], wc[1], wc[2] };
            } else mesh.bounding_center;
            const radius = mesh.bounding_radius;
            const cam_pos = view.cam_pos;
            if (view.max_draw_distance) |max_dist| {
                if (view.cam_pos == null) continue;
                const dx = world_center[0] - cam_pos.?[0];
                const dy = world_center[1] - cam_pos.?[1];
                const dz = world_center[2] - cam_pos.?[2];
                if (dx * dx + dy * dy + dz * dz > max_dist * max_dist) continue;
            }
            const skip_culling = view.id == .skybox or view.id == .@"2d" or view.id == .ui;

            if (!skip_culling and !frustum.containsSphere(world_center[0], world_center[1], world_center[2], radius)) {
                continue; // cull
            }

            const arr = math.matToArr(cmd.transform);
            _ = bgfx.setTransform(&arr, 1);

            const mat = if (mesh.material) |m| m else self.materials.getPtr(.unlit).?;
            const state = bgfx.StateFlags_WriteRgb |
                bgfx.StateFlags_WriteA |
                bgfx.StateFlags_WriteZ |
                bgfx.StateFlags_DepthTestLess;
            bgfx.setState(state, 0);
            const owned_texture = assets.getAsset(@import("../assets/Image.zig"), mesh.texture);
            if (owned_texture) |tex| {
                bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
                mat.bindWithoutTexture();
            } else {
                mat.bind(self.tex_uniform, &self.white_texture);
            }

            bgfx.setVertexBuffer(0, mesh.vbh, 0, mesh.num_vertices);
            bgfx.setIndexBuffer(mesh.ibh, 0, mesh.num_indices);
            _ = bgfx.submit(view_id, mat.program.program_handle, 0, bgfx.DiscardFlags_All);
        }

        // dynamic meshes
        for (view.dynamic_meshes.items) |mesh| {
            if (mesh.transform) |t| {
                _ = bgfx.setTransform(&math.matToArr(zm.transpose(t)), 1);
            }
            const mat = if (mesh.material) |m| m else self.materials.getPtr(.unlit).?;
            const state = bgfx.StateFlags_WriteRgb |
                bgfx.StateFlags_WriteA |
                bgfx.StateFlags_WriteZ |
                bgfx.StateFlags_DepthTestLess;
            bgfx.setState(state, 0);
            if (mesh.owned_texture) |*tex| {
                bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
                mat.bindWithoutTexture();
            } else {
                mat.bind(self.tex_uniform, &self.white_texture);
            }

            if (mesh.owned_texture) |*tex| {
                bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
                mat.bindWithoutTexture();
            } else {
                mat.bind(self.tex_uniform, &self.white_texture);
            }

            bgfx.setDynamicVertexBuffer(0, mesh.vbh, 0, mesh.num_vertices);
            bgfx.setDynamicIndexBuffer(mesh.ibh, 0, mesh.num_indices);
            _ = bgfx.submit(view_id, mat.program.program_handle, 0, bgfx.DiscardFlags_All);
        }
        // transient submissions
        for (view.transient_submissions.items) |sub| {
            if (sub.transform) |t| {
                _ = bgfx.setTransform(&math.matToArr(zm.transpose(t)), 1);
            }
            const state = bgfx.StateFlags_WriteRgb |
                bgfx.StateFlags_WriteA |
                bgfx.StateFlags_WriteZ |
                bgfx.StateFlags_DepthTestLess;
            bgfx.setState(state, 0);
            if (sub.texture) |tex| {
                bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
            } else {
                bgfx.setTexture(0, self.tex_uniform, self.white_texture.handle, std.math.maxInt(u32));
            }
            var tvb: bgfx.TransientVertexBuffer = undefined;
            var tib: bgfx.TransientIndexBuffer = undefined;
            if (!bgfx.allocTransientBuffers(&tvb, &self.vertex_layout, @intCast(sub.vertices.len), &tib, @intCast(sub.indices.len), false)) {
                log.err("Failed to allocate transient buffers", .{});
                continue;
            }
            @memcpy(tvb.data[0..(@sizeOf(Vertex) * sub.vertices.len)], std.mem.sliceAsBytes(sub.vertices));
            @memcpy(tib.data[0..(sub.indices.len * 2)], std.mem.sliceAsBytes(sub.indices));
            bgfx.setTransientVertexBuffer(0, &tvb, 0, @intCast(sub.vertices.len));
            bgfx.setTransientIndexBuffer(&tib, 0, @intCast(sub.indices.len));
            _ = bgfx.submit(view_id, self.unlit_program.program_handle, 0, bgfx.DiscardFlags_All);
        }

        // clear
        for (view.transient_submissions.items) |sub| {
            self.allocator.free(sub.vertices);
            self.allocator.free(sub.indices);
        }
        view.transient_submissions.clearRetainingCapacity();
    }

    fn setState(self: *Renderer, texture: ?*const Image, blend: bool) void {
        var state = bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA;

        if (!blend) {
            state |= bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess;
        } else {
            // No depth test/write for blended UI
            state |= stateBlendFunc(bgfx.StateFlags_BlendSrcAlpha, bgfx.StateFlags_BlendInvSrcAlpha);
        }

        bgfx.setState(state, 0);
        if (texture) |tex| {
            bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
        } else {
            bgfx.setTexture(0, self.tex_uniform, self.white_texture.handle, std.math.maxInt(u32));
        }
    }

    pub fn deinit(self: *Renderer) void {
        self.unlit_program.deinit();
        self.white_texture.deinit();
        var mat_iter = self.materials.iterator();
        while (mat_iter.next()) |entry| {
            entry.value.deinit();
        }
        bgfx.destroyUniform(self.tex_uniform);
        bgfx.shutdown();

        var view_iter = self.views.iterator();
        while (view_iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.views.deinit();
        self.allocator.destroy(self);
    }
};

pub fn stateBlendFunc(src: u64, dst: u64) u64 {
    const shift = bgfx.StateFlags_BlendShift;
    const src_raw = src >> shift;
    const dst_raw = dst >> shift;
    return (dst_raw | (src_raw << 4)) << shift;
}
