const std = @import("std");
const c = @cImport({
    @cInclude("bgfx/c99/bgfx.h");
});
const callbacks = @import("callbacks.zig");

const bgfx = @import("bgfx.zig");
const shader_src = @import("renderer-shaders");
const ShaderProgram = @import("shader.zig").ShaderProgram;
const log = std.log.scoped(.renderer);
pub const Font = @import("font.zig").Font;
var bgfx_clbs = callbacks.CCallbackInterfaceT{
    .vtable = &callbacks.default_callback_vtable,
};

const stb = @import("../root.zig").c.stb;
pub const Math = struct {
    pub const Vec2 = struct { x: f32, y: f32 };
    pub const Vec3 = struct { x: f32, y: f32, z: f32 };
    pub const Mat4 = [16]f32;

    pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }
    pub fn vec3Add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }
    pub fn vec3Sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }
    pub fn vec3Dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }
    pub fn vec3Cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }
    pub fn vec3Normalize(v: Vec3) Vec3 {
        const len = @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
        if (len == 0.0) return v;
        return .{ .x = v.x / len, .y = v.y / len, .z = v.z / len };
    }

    pub fn mat4Identity() Mat4 {
        var m = std.mem.zeroes(Mat4);
        m[0] = 1.0;
        m[5] = 1.0;
        m[10] = 1.0;
        m[15] = 1.0;
        return m;
    }

    pub fn mat4Ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        var m = mat4Identity();
        m[0] = 2.0 / (right - left);
        m[5] = 2.0 / (top - bottom);
        m[10] = -2.0 / (far - near);
        m[12] = -(right + left) / (right - left);
        m[13] = -(top + bottom) / (top - bottom);
        m[14] = -(far + near) / (far - near);
        return m;
    }

    pub fn mat4Perspective(fovy: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fovy = @tan(fovy * 0.5 * std.math.pi / 180.0);
        var m = std.mem.zeroes(Mat4);
        m[0] = 1.0 / (aspect * tan_half_fovy);
        m[5] = 1.0 / tan_half_fovy;
        m[10] = -(far + near) / (far - near);
        m[11] = -1.0;
        m[14] = -(2.0 * far * near) / (far - near);
        return m;
    }

    pub fn mat4LookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = vec3Normalize(vec3Sub(center, eye));
        const s = vec3Normalize(vec3Cross(f, up));
        const u = vec3Cross(s, f);
        var m = mat4Identity();
        m[0] = s.x;
        m[4] = s.y;
        m[8] = s.z;
        m[1] = u.x;
        m[5] = u.y;
        m[9] = u.z;
        m[2] = -f.x;
        m[6] = -f.y;
        m[10] = -f.z;
        m[12] = -vec3Dot(s, eye);
        m[13] = -vec3Dot(u, eye);
        m[14] = vec3Dot(f, eye);
        return m;
    }
};

// ============================================================================
// Core Types & Resources
// ============================================================================

pub const ViewID = struct {
    pub const SCENE_3D: u16 = 0;
    pub const UI_2D: u16 = 1;
};

pub const Views = enum(u16) {
    scene_3d = 0,
    ui_2d = 1,
};

pub const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    u: f32,
    v: f32,
    abgr: u32,

    var layout: c.bgfx_vertex_layout_t = undefined;

    pub fn initLayout() void {
        _ = c.bgfx_vertex_layout_begin(&layout, c.BGFX_RENDERER_TYPE_NOOP);
        _ = c.bgfx_vertex_layout_add(&layout, c.BGFX_ATTRIB_POSITION, 3, c.BGFX_ATTRIB_TYPE_FLOAT, false, false);
        _ = c.bgfx_vertex_layout_add(&layout, c.BGFX_ATTRIB_TEXCOORD0, 2, c.BGFX_ATTRIB_TYPE_FLOAT, false, false);
        _ = c.bgfx_vertex_layout_add(&layout, c.BGFX_ATTRIB_COLOR0, 4, c.BGFX_ATTRIB_TYPE_UINT8, true, false);
        _ = c.bgfx_vertex_layout_end(&layout);
    }
};

pub const Mesh = struct {
    vbh: c.bgfx_vertex_buffer_handle_t,
    ibh: c.bgfx_index_buffer_handle_t,

    pub fn create(vertices: []const Vertex, indices: []const u16) Mesh {
        const mem_v = c.bgfx_copy(vertices.ptr, @intCast(vertices.len * @sizeOf(Vertex)));
        const mem_i = c.bgfx_copy(indices.ptr, @intCast(indices.len * @sizeOf(u16)));
        return .{
            .vbh = c.bgfx_create_vertex_buffer(mem_v, &Vertex.layout, c.BGFX_BUFFER_NONE),
            .ibh = c.bgfx_create_index_buffer(mem_i, c.BGFX_BUFFER_NONE),
        };
    }

    pub fn destroy(self: *const Mesh) void {
        c.bgfx_destroy_vertex_buffer(self.vbh);
        c.bgfx_destroy_index_buffer(self.ibh);
    }
};

pub const Camera3D = struct {
    position: Math.Vec3,
    target: Math.Vec3,
    up: Math.Vec3 = Math.vec3(0.0, 1.0, 0.0),
    fovy: f32 = 60.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,

    pub fn getViewMatrix(self: *const Camera3D) Math.Mat4 {
        return Math.mat4LookAt(self.position, self.target, self.up);
    }

    pub fn getProjMatrix(self: *const Camera3D, aspect: f32) Math.Mat4 {
        return Math.mat4Perspective(self.fovy, aspect, self.near, self.far);
    }
};

// ============================================================================
// The Renderer
// ============================================================================

pub const Renderer = struct {
    width: u16,
    height: u16,

    // Programs
    shader: ShaderProgram,
    u_texColor: bgfx.UniformHandle,

    batch_vertices: [MAX_VERTICES]Vertex = undefined,
    batch_indices: [MAX_INDICES]u16 = undefined,
    vertex_count: u16 = 0,
    index_count: u16 = 0,
    white_texture: bgfx.TextureHandle,
    current_texture: c.bgfx_texture_handle_t = .{ .idx = std.math.maxInt(u16) },
    // 2D Batcher State
    const MAX_QUADS = 4096;
    const MAX_VERTICES = MAX_QUADS * 4;
    const MAX_INDICES = MAX_QUADS * 6;
    const Self = @This();

    pub fn init(native_window_handle: *anyopaque, width: u16, height: u16) !Self {
        var init_data = std.mem.zeroes(bgfx.Init);
        bgfx.initCtor(&init_data);

        init_data.platformData.nwh = native_window_handle;
        init_data.resolution.width = @intCast(width);
        init_data.resolution.height = @intCast(height);
        init_data.resolution.reset = bgfx.ResetFlags_Vsync;
        init_data.debug = true;
        init_data.callback = &callbacks.BgfxCallbacks.interface;
        if (!bgfx.init(&init_data)) {
            return error.BgfxInitFailed;
        }

        bgfx.setDebug(bgfx.DebugFlags_Text | bgfx.DebugFlags_Stats);

        std.debug.print("callback ptr: {*}\n", .{init_data.callback});

        Vertex.initLayout();

        const backend = bgfx.getRendererType();
        log.info("Using renderer backend of {s} \n", .{bgfx.getRendererName(backend)});
        const shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shader_src.directx.vs_basic, shader_src.directx.fs_basic),
            .Metal => ShaderProgram.init(shader_src.metal.vs_basic, shader_src.metal.fs_basic),
            .Vulkan => ShaderProgram.init(shader_src.vulkan.vs_basic, shader_src.vulkan.fs_basic),
            .OpenGL => ShaderProgram.init(shader_src.opengl.vs_basic, shader_src.opengl.fs_basic),
            else => return error.UnsupportedRendererBackend,
        };

        c.bgfx_set_view_clear(ViewID.SCENE_3D, c.BGFX_CLEAR_COLOR | c.BGFX_CLEAR_DEPTH, 0x303030ff, 1.0, 0);
        c.bgfx_set_view_clear(ViewID.UI_2D, c.BGFX_CLEAR_NONE, 0, 1.0, 0);

        const u_texColor = bgfx.createUniform("s_texColor", .Sampler, 1); //c.bgfx_create_uniform("s_texColor", c.BGFX_UNIFORM_TYPE_SAMPLER, 1);

        const white_pixel = [_]u32{0xFFFFFFFF};
        const white_mem = bgfx.copy(&white_pixel, @sizeOf(u32));
        const white_texture = bgfx.createTexture2D(1, 1, false, 1, .RGBA8, 0, white_mem, 0);

        return Self{
            .width = width,
            .height = height,
            .shader = shader,
            .white_texture = white_texture,
            // .program_basic = program_basic,
            .u_texColor = u_texColor,
        };
    }

    pub fn resize(self: *Self, width: u16, height: u16) void {
        self.width = width;
        self.height = height;
        c.bgfx_reset(width, height, c.BGFX_RESET_VSYNC, c.BGFX_TEXTURE_FORMAT_COUNT);
        c.bgfx_set_view_rect(ViewID.SCENE_3D, 0, 0, width, height);
        c.bgfx_set_view_rect(ViewID.UI_2D, 0, 0, width, height);
    }

    pub fn beginFrame(self: *Self, camera_3d: ?Camera3D) void {
        c.bgfx_set_view_rect(ViewID.SCENE_3D, 0, 0, self.width, self.height);
        c.bgfx_set_view_rect(ViewID.UI_2D, 0, 0, self.width, self.height);
        c.bgfx_touch(ViewID.SCENE_3D);
        c.bgfx_touch(ViewID.UI_2D); // ← also touch UI_2D!

        // c.bgfx_touch(ViewID.SCENE_3D);

        if (camera_3d) |cam| {
            const aspect = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
            const view = cam.getViewMatrix();
            const proj = cam.getProjMatrix(aspect);
            c.bgfx_set_view_transform(ViewID.SCENE_3D, &view, &proj);
        }

        const ortho = Math.mat4Ortho(0.0, @floatFromInt(self.width), @floatFromInt(self.height), 0.0, -1.0, 1.0);
        var identity_view = Math.mat4Identity();
        c.bgfx_set_view_transform(ViewID.UI_2D, &identity_view, &ortho);
    }

    pub fn endFrame(self: *Self) void {
        self.flush2D();
        _ = c.bgfx_frame(false);
    }

    // ========================================================================
    // 3D Rendering API
    // ========================================================================

    pub fn drawMesh3D(self: *Self, mesh: Mesh, transform: Math.Mat4) void {
        c.bgfx_set_transform(&transform, 1);
        c.bgfx_set_vertex_buffer(0, mesh.vbh, 0, std.math.maxInt(u32));
        c.bgfx_set_index_buffer(mesh.ibh, 0, std.math.maxInt(u32));

        const state = c.BGFX_STATE_DEFAULT | c.BGFX_STATE_DEPTH_TEST_LESS | c.BGFX_STATE_CULL_CW;
        c.bgfx_set_state(state, 0);

        c.bgfx_submit(ViewID.SCENE_3D, self.program_basic, 0, c.BGFX_DISCARD_ALL);
    }

    // ========================================================================
    // 2D Batching & Primitives API
    // ========================================================================

    pub fn flush2D(self: *Self) void {
        if (self.vertex_count == 0) return;

        var tvb: c.bgfx_transient_vertex_buffer_t = undefined;
        var tib: c.bgfx_transient_index_buffer_t = undefined;
        c.bgfx_alloc_transient_vertex_buffer(&tvb, self.vertex_count, &Vertex.layout);
        c.bgfx_alloc_transient_index_buffer(&tib, self.index_count, false);
        const v_dst = @as([*]Vertex, @ptrCast(@alignCast(tvb.data)));
        @memcpy(v_dst[0..self.vertex_count], self.batch_vertices[0..self.vertex_count]);

        const i_dst = @as([*]u16, @ptrCast(@alignCast(tib.data)));
        @memcpy(i_dst[0..self.index_count], self.batch_indices[0..self.index_count]);

        c.bgfx_set_transient_vertex_buffer(0, &tvb, 0, self.vertex_count);
        c.bgfx_set_transient_index_buffer(&tib, 0, self.index_count);

        // Always bind a valid texture
        const tex_to_bind = if (self.current_texture.idx != std.math.maxInt(u16))
            bgfx.TextureHandle{ .idx = @intCast(self.current_texture.idx) }
        else
            self.white_texture;

        bgfx.setTexture(0, self.u_texColor, tex_to_bind, std.math.maxInt(u32));

        const state = c.BGFX_STATE_WRITE_RGB | c.BGFX_STATE_WRITE_A | c.BGFX_STATE_BLEND_ALPHA;
        c.bgfx_set_state(state, 0);
        bgfx.submit(ViewID.UI_2D, self.shader.program_handle, 0, bgfx.DiscardFlags_All);

        self.vertex_count = 0;
        self.index_count = 0;
    }

    fn checkBatchLimits(self: *Self, tex: c.bgfx_texture_handle_t, required_verts: u16, required_indices: u16) void {
        if (self.vertex_count + required_verts > MAX_VERTICES or
            self.index_count + required_indices > MAX_INDICES or
            self.current_texture.idx != tex.idx)
        {
            self.flush2D();
        }
        self.current_texture = tex;
    }

    pub fn drawTexture2D(self: *Self, tex: c.bgfx_texture_handle_t, x: f32, y: f32, w: f32, h: f32, color: u32) void {
        self.checkBatchLimits(tex, 4, 6);

        const v_idx = self.vertex_count;
        self.batch_vertices[v_idx + 0] = .{ .x = x, .y = y, .z = 0, .u = 0.0, .v = 0.0, .abgr = color };
        self.batch_vertices[v_idx + 1] = .{ .x = x + w, .y = y, .z = 0, .u = 1.0, .v = 0.0, .abgr = color };
        self.batch_vertices[v_idx + 2] = .{ .x = x + w, .y = y + h, .z = 0, .u = 1.0, .v = 1.0, .abgr = color };
        self.batch_vertices[v_idx + 3] = .{ .x = x, .y = y + h, .z = 0, .u = 0.0, .v = 1.0, .abgr = color };

        const i_idx = self.index_count;
        self.batch_indices[i_idx + 0] = v_idx + 0;
        self.batch_indices[i_idx + 1] = v_idx + 1;
        self.batch_indices[i_idx + 2] = v_idx + 2;
        self.batch_indices[i_idx + 3] = v_idx + 2;
        self.batch_indices[i_idx + 4] = v_idx + 3;
        self.batch_indices[i_idx + 5] = v_idx + 0;

        self.vertex_count += 4;
        self.index_count += 6;
    }

    pub fn drawQuad2D(self: *Self, x: f32, y: f32, w: f32, h: f32, color: u32) void {
        const invalid_tex = c.bgfx_texture_handle_t{ .idx = std.math.maxInt(u16) };
        self.drawTexture2D(invalid_tex, x, y, w, h, color);
    }

    // --- New: Thick Line Primitive ---
    pub fn drawLine2D(self: *Self, x1: f32, y1: f32, x2: f32, y2: f32, thickness: f32, color: u32) void {
        const invalid_tex = c.bgfx_texture_handle_t{ .idx = std.math.maxInt(u16) };
        self.checkBatchLimits(invalid_tex, 4, 6);

        const dx = x2 - x1;
        const dy = y2 - y1;
        const len = @sqrt(dx * dx + dy * dy);
        if (len == 0.0) return;

        const nx = -(dy / len) * (thickness * 0.5);
        const ny = (dx / len) * (thickness * 0.5);

        const v_idx = self.vertex_count;
        self.batch_vertices[v_idx + 0] = .{ .x = x1 + nx, .y = y1 + ny, .z = 0, .u = 0.0, .v = 0.0, .abgr = color };
        self.batch_vertices[v_idx + 1] = .{ .x = x2 + nx, .y = y2 + ny, .z = 0, .u = 0.0, .v = 0.0, .abgr = color };
        self.batch_vertices[v_idx + 2] = .{ .x = x2 - nx, .y = y2 - ny, .z = 0, .u = 0.0, .v = 0.0, .abgr = color };
        self.batch_vertices[v_idx + 3] = .{ .x = x1 - nx, .y = y1 - ny, .z = 0, .u = 0.0, .v = 0.0, .abgr = color };

        const i_idx = self.index_count;
        self.batch_indices[i_idx + 0] = v_idx + 0;
        self.batch_indices[i_idx + 1] = v_idx + 1;
        self.batch_indices[i_idx + 2] = v_idx + 2;
        self.batch_indices[i_idx + 3] = v_idx + 2;
        self.batch_indices[i_idx + 4] = v_idx + 3;
        self.batch_indices[i_idx + 5] = v_idx + 0;

        self.vertex_count += 4;
        self.index_count += 6;
    }

    pub fn drawCircle2D(self: *Self, x: f32, y: f32, radius: f32, segments: u16, color: u32) void {
        const invalid_tex = c.bgfx_texture_handle_t{ .idx = std.math.maxInt(u16) };
        const req_verts = segments + 1;
        const req_indices = segments * 3;
        self.checkBatchLimits(invalid_tex, req_verts, req_indices);

        const v_idx = self.vertex_count;
        const i_idx = self.index_count;

        // Center vertex
        self.batch_vertices[v_idx] = .{ .x = x, .y = y, .z = 0, .u = 0, .v = 0, .abgr = color };

        const step = (std.math.pi * 2.0) / @as(f32, @floatFromInt(segments));
        for (0..segments) |i| {
            const theta = @as(f32, @floatFromInt(i)) * step;
            const cx = x + radius * @cos(theta);
            const cy = y + radius * @sin(theta);
            self.batch_vertices[v_idx + 1 + i] = .{ .x = cx, .y = cy, .z = 0, .u = 0, .v = 0, .abgr = color };

            self.batch_indices[i_idx + (i * 3) + 0] = v_idx;
            self.batch_indices[i_idx + (i * 3) + 1] = v_idx + 1 + @as(u16, @intCast(i));
            self.batch_indices[i_idx + (i * 3) + 2] = v_idx + 1 + @as(u16, @intCast((i + 1) % segments));
        }

        self.vertex_count += req_verts;
        self.index_count += req_indices;
    }

    pub fn deinit(self: *Self) void {
        bgfx.destroyTexture(self.white_texture);
        self.shader.deinit();
        bgfx.destroyUniform(self.u_texColor);
        bgfx.shutdown();
    }

    pub fn drawText2D(self: *Self, font: *const Font, text: []const u8, start_x: f32, start_y: f32, color: u32) void {
        var x = start_x;
        var y = start_y;

        for (text) |char| {
            if (char >= 32 and char < 128) {
                var q: stb.stbtt_aligned_quad = undefined;
                stb.stbtt_GetBakedQuad(@constCast(font.cdata[0..].ptr), // stbtt doesn't like const ptrs here
                    font.atlas_size, font.atlas_size, @as(i32, char) - 32, &x, &y, &q, 1);

                const tt = @as(*c.bgfx_texture_handle_t, @ptrCast(@alignCast(@constCast(&font.texture))));

                self.checkBatchLimits(tt.*, 4, 6);

                const v_idx = self.vertex_count;
                self.batch_vertices[v_idx + 0] = .{ .x = q.x0, .y = q.y0, .z = 0, .u = q.s0, .v = q.t0, .abgr = color };
                self.batch_vertices[v_idx + 1] = .{ .x = q.x1, .y = q.y0, .z = 0, .u = q.s1, .v = q.t0, .abgr = color };
                self.batch_vertices[v_idx + 2] = .{ .x = q.x1, .y = q.y1, .z = 0, .u = q.s1, .v = q.t1, .abgr = color };
                self.batch_vertices[v_idx + 3] = .{ .x = q.x0, .y = q.y1, .z = 0, .u = q.s0, .v = q.t1, .abgr = color };

                const i_idx = self.index_count;
                self.batch_indices[i_idx + 0] = v_idx + 0;
                self.batch_indices[i_idx + 1] = v_idx + 1;
                self.batch_indices[i_idx + 2] = v_idx + 2;
                self.batch_indices[i_idx + 3] = v_idx + 2;
                self.batch_indices[i_idx + 4] = v_idx + 3;
                self.batch_indices[i_idx + 5] = v_idx + 0;

                self.vertex_count += 4;
                self.index_count += 6;
            }
        }
    }
};

// ============================================================================
// 3D Primitive Generators
// ============================================================================

pub const PrimitiveMeshes = struct {
    pub fn createCube() Mesh {
        const verts = [_]Vertex{
            // Front
            .{ .x = -1, .y = -1, .z = 1, .u = 0, .v = 0, .abgr = 0xFFFFFFFF },
            .{ .x = 1, .y = -1, .z = 1, .u = 1, .v = 0, .abgr = 0xFFFFFFFF },
            .{ .x = 1, .y = 1, .z = 1, .u = 1, .v = 1, .abgr = 0xFFFFFFFF },
            .{ .x = -1, .y = 1, .z = 1, .u = 0, .v = 1, .abgr = 0xFFFFFFFF },
            // Back
            .{ .x = -1, .y = -1, .z = -1, .u = 0, .v = 0, .abgr = 0xFFFFFFFF },
            .{ .x = 1, .y = -1, .z = -1, .u = 1, .v = 0, .abgr = 0xFFFFFFFF },
            .{ .x = 1, .y = 1, .z = -1, .u = 1, .v = 1, .abgr = 0xFFFFFFFF },
            .{ .x = -1, .y = 1, .z = -1, .u = 0, .v = 1, .abgr = 0xFFFFFFFF },
        };
        const indices = [_]u16{
            0, 1, 2, 2, 3, 0, // Front
            5, 4, 7, 7, 6, 5, // Back
            4, 0, 3, 3, 7, 4, // Left
            1, 5, 6, 6, 2, 1, // Right
            3, 2, 6, 6, 7, 3, // Top
            4, 5, 1, 1, 0, 4, // Bottom
        };
        return Mesh.create(&verts, &indices);
    }
};
