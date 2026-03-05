pub const bgfx = @import("bgfx.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
pub const math = @import("math");
pub const ShaderProgram = @import("shader.zig").ShaderProgram;
const shaders = @import("renderer-shaders");

pub const Font = @import("font.zig").Font;

pub const VIEW_SCENE: bgfx.ViewId = 0;
pub const VIEW_HUD: bgfx.ViewId = 1;
pub const VIEW_POST_BASE: bgfx.ViewId = 2;
pub const MAX_POST_PASSES = 16;

pub const UniformValue = struct {
    name: []const u8,
    value: union(enum) {
        vec4: [4]f32,
        mat4: [16]f32,
    },
};

pub const PassConfig = union(enum) {
    bloom: struct { threshold: f32 = 0.8, intensity: f32 = 1.0, radius: f32 = 1.0 },
    vignette: struct { strength: f32 = 0.4, radius: f32 = 0.75 },
    tonemap: struct { exposure: f32 = 1.0 },
    fxaa: struct {},
    custom: struct {
        shader: ShaderProgram,
        uniforms: []UniformValue, // owned by renderer allocator
    },
};

pub const PassHandle = u8;

const Pass = struct {
    config: PassConfig,
    enabled: bool = true,
};

pub const Camera = struct {
    position: math.Vec3,
    yaw_rad: f32,
    pitch_rad: f32,
    roll_rad: f32,

    pub fn firstPerson(position: math.Vec3) Camera {
        return .{ .position = position, .yaw_rad = 0, .pitch_rad = 0, .roll_rad = 0 };
    }
    pub fn thirdPerson(target: math.Vec3, distance: f32, yaw: f32, pitch: f32) Camera {
        const dir = forwardFromAngles(yaw, pitch);
        const pos = math.Vec3.init(
            target.x() - dir.x() * distance,
            target.y() - dir.y() * distance,
            target.z() - dir.z() * distance,
        );
        return .{ .position = pos, .yaw_rad = yaw, .pitch_rad = pitch, .roll_rad = 0 };
    }
    pub fn flight(position: math.Vec3, yaw: f32, pitch: f32, roll: f32) Camera {
        return .{ .position = position, .yaw_rad = yaw, .pitch_rad = pitch, .roll_rad = roll };
    }
    pub fn orbital(target: math.Vec3, distance: f32, yaw: f32, pitch: f32) Camera {
        return thirdPerson(target, distance, yaw, pitch);
    }
    pub fn topDown(position: math.Vec3) Camera {
        return .{ .position = position, .yaw_rad = 0, .pitch_rad = -std.math.pi * 0.5, .roll_rad = 0 };
    }
    pub fn moveForward(self: *Camera, amount: f32) void {
        const f = self.forward();
        self.position = math.Vec3.init(
            self.position.x() + f.x() * amount,
            self.position.y() + f.y() * amount,
            self.position.z() + f.z() * amount,
        );
    }
    pub fn moveRight(self: *Camera, amount: f32) void {
        const r = self.right();
        self.position = math.Vec3.init(
            self.position.x() + r.x() * amount,
            self.position.y() + r.y() * amount,
            self.position.z() + r.z() * amount,
        );
    }
    pub fn moveUp(self: *Camera, amount: f32) void {
        self.position = math.Vec3.init(self.position.x(), self.position.y() + amount, self.position.z());
    }
    pub fn addYaw(self: *Camera, radians: f32) void {
        self.yaw_rad += radians;
    }
    pub fn addPitch(self: *Camera, radians: f32) void {
        const limit = std.math.pi * 0.499;
        self.pitch_rad = std.math.clamp(self.pitch_rad + radians, -limit, limit);
    }
    pub fn addRoll(self: *Camera, radians: f32) void {
        self.roll_rad += radians;
    }
    pub fn forward(self: Camera) math.Vec3 {
        return forwardFromAngles(self.yaw_rad, self.pitch_rad);
    }
    pub fn right(self: Camera) math.Vec3 {
        return self.forward().cross(&math.vec3(0, 1, 0)).normalize(0);
    }
    pub fn up(self: Camera) math.Vec3 {
        return self.right().cross(&self.forward()).normalize(0);
    }
    pub fn viewMatrix(self: Camera) math.Mat4x4 {
        const f = self.forward();
        const r = self.right();
        const u = if (self.roll_rad != 0) self.up() else math.vec3(0, 1, 0);
        var m = math.Mat4x4.ident;
        m.v[0].v[0] = r.x();
        m.v[1].v[0] = r.y();
        m.v[2].v[0] = r.z();
        m.v[0].v[1] = u.x();
        m.v[1].v[1] = u.y();
        m.v[2].v[1] = u.z();
        m.v[0].v[2] = f.x();
        m.v[1].v[2] = f.y();
        m.v[2].v[2] = f.z();
        m.v[3].v[0] = -r.dot(&self.position);
        m.v[3].v[1] = -u.dot(&self.position);
        m.v[3].v[2] = -f.dot(&self.position);
        return m;
    }
    fn forwardFromAngles(yaw: f32, pitch: f32) math.Vec3 {
        return math.Vec3.init(
            @cos(pitch) * @sin(yaw),
            @sin(pitch),
            @cos(pitch) * @cos(yaw),
        ).normalize(0);
    }
};

// ----------------------------------------------------------------
// Transform
// ----------------------------------------------------------------

pub const Transform = struct {
    position: math.Vec3,
    rotation: math.Vec3,
    scale: math.Vec3,

    pub fn init(position: math.Vec3, rotation: math.Vec3, scale: math.Vec3) Transform {
        return .{ .position = position, .rotation = rotation, .scale = scale };
    }
    pub fn identity() Transform {
        return .{ .position = math.vec3(0, 0, 0), .rotation = math.vec3(0, 0, 0), .scale = math.vec3(1, 1, 1) };
    }
    pub fn at(position: math.Vec3) Transform {
        return .{ .position = position, .rotation = math.vec3(0, 0, 0), .scale = math.vec3(1, 1, 1) };
    }
    pub fn toMatrix(self: Transform) math.Mat4x4 {
        const t = math.Mat4x4.translate(self.position);
        const rx = math.Mat4x4.rotateX(self.rotation.x());
        const ry = math.Mat4x4.rotateY(self.rotation.y());
        const rz = math.Mat4x4.rotateZ(self.rotation.z());
        const s = math.Mat4x4.scale(self.scale);
        return t.mul(&ry).mul(&rx).mul(&rz).mul(&s);
    }
};

pub const Vertex = extern struct {
    x: f32,
    y: f32,
    z: f32,
    color: u32,
    u: f32,
    v: f32,
};

const Batch = struct {
    view: u8,
    texture: bgfx.TextureHandle,
    vertex_start: u32,
    vertex_count: u32,
    index_start: u32,
    index_count: u32,
    transform: math.Mat4x4,
};

pub const Renderer = struct {
    allocator: Allocator,
    width: u32,
    height: u32,

    // Core
    shader: ShaderProgram,
    layout: bgfx.VertexLayout,
    sampler: bgfx.UniformHandle,
    white_texture: bgfx.TextureHandle,
    view3d: math.Mat4x4,
    proj3d: math.Mat4x4,
    fov_y: f32,
    near: f32,
    far: f32,

    // Geometry buffers
    vertices: std.ArrayListUnmanaged(Vertex),
    indices: std.ArrayListUnmanaged(u16),
    batches: std.ArrayListUnmanaged(Batch),

    // Post-processing
    scene_fb: bgfx.FrameBufferHandle,
    ping_fb: bgfx.FrameBufferHandle,
    pong_fb: bgfx.FrameBufferHandle,
    bloom_shader: ShaderProgram,
    vignette_shader: ShaderProgram,
    tonemap_shader: ShaderProgram,
    fxaa_shader: ShaderProgram,
    u_post_params: bgfx.UniformHandle,
    u_post_params2: bgfx.UniformHandle,
    u_src_tex: bgfx.UniformHandle,
    passes: std.ArrayListUnmanaged(Pass),

    pub fn init(config: struct {
        native_handle: *anyopaque,
        allocator: Allocator,
        width: u32,
        height: u32,
    }) !Renderer {
        var b_init = std.mem.zeroes(bgfx.Init);
        bgfx.initCtor(&b_init);
        b_init.type = .Vulkan;
        b_init.platformData.nwh = config.native_handle;
        b_init.resolution.width = config.width;
        b_init.resolution.height = config.height;
        b_init.resolution.reset = bgfx.ResetFlags_None;
        if (!bgfx.init(&b_init)) return error.BgfxInitFailed;

        bgfx.setDebug(bgfx.DebugFlags_Stats);

        const backend = bgfx.getRendererType();
        std.log.info("bgfx backend: {s}", .{bgfx.getRendererName(backend)});

        var layout: bgfx.VertexLayout = undefined;
        _ = layout.begin(backend);
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.Color0, 4, .Uint8, true, true);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        layout.end();

        const shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shaders.directx.vs_basic, shaders.directx.fs_basic),
            .OpenGL => ShaderProgram.init(shaders.opengl.vs_basic, shaders.opengl.fs_basic),
            .Vulkan => ShaderProgram.init(shaders.vulkan.vs_basic, shaders.vulkan.fs_basic),
            else => return error.UnsupportedBackend,
        };
        const bloom_shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shaders.directx.vs_fullscreen, shaders.directx.fs_bloom),
            .OpenGL => ShaderProgram.init(shaders.opengl.vs_fullscreen, shaders.opengl.fs_bloom),
            .Vulkan => ShaderProgram.init(shaders.vulkan.vs_fullscreen, shaders.vulkan.fs_bloom),
            else => return error.UnsupportedBackend,
        };
        const vignette_shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shaders.directx.vs_fullscreen, shaders.directx.fs_vignette),
            .OpenGL => ShaderProgram.init(shaders.opengl.vs_fullscreen, shaders.opengl.fs_vignette),
            .Vulkan => ShaderProgram.init(shaders.vulkan.vs_fullscreen, shaders.vulkan.fs_vignette),
            else => return error.UnsupportedBackend,
        };
        const tonemap_shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shaders.directx.vs_fullscreen, shaders.directx.fs_tonemap),
            .OpenGL => ShaderProgram.init(shaders.opengl.vs_fullscreen, shaders.opengl.fs_tonemap),
            .Vulkan => ShaderProgram.init(shaders.vulkan.vs_fullscreen, shaders.vulkan.fs_tonemap),
            else => return error.UnsupportedBackend,
        };
        const fxaa_shader = switch (backend) {
            .Direct3D11, .Direct3D12 => ShaderProgram.init(shaders.directx.vs_fullscreen, shaders.directx.fs_fxaa),
            .OpenGL => ShaderProgram.init(shaders.opengl.vs_fullscreen, shaders.opengl.fs_fxaa),
            .Vulkan => ShaderProgram.init(shaders.vulkan.vs_fullscreen, shaders.vulkan.fs_fxaa),
            else => return error.UnsupportedBackend,
        };

        const sampler = bgfx.createUniform("s_texColor", .Sampler, 1);
        const u_src_tex = bgfx.createUniform("s_srcTex", .Sampler, 1);
        const u_post_params = bgfx.createUniform("u_postParams", .Vec4, 1);
        const u_post_params2 = bgfx.createUniform("u_postParams2", .Vec4, 1);

        const white: u32 = 0xFFFFFFFF;
        const white_texture = bgfx.createTexture2D(1, 1, false, 1, .RGBA8, 0, bgfx.copy(&white, @sizeOf(u32)), 0);

        const w: f32 = @floatFromInt(config.width);
        const h: f32 = @floatFromInt(config.height);
        const fov: f32 = std.math.pi / 3.0;

        return .{
            .allocator = config.allocator,
            .width = config.width,
            .height = config.height,
            .shader = shader,
            .layout = layout,
            .sampler = sampler,
            .white_texture = white_texture,
            .view3d = math.Mat4x4.ident,
            .proj3d = buildProj(fov, w / h, 0.1, 1000.0),
            .fov_y = fov,
            .near = 0.1,
            .far = 1000.0,
            .vertices = try std.ArrayListUnmanaged(Vertex).initCapacity(config.allocator, 4096),
            .indices = try std.ArrayListUnmanaged(u16).initCapacity(config.allocator, 4096),
            .batches = try std.ArrayListUnmanaged(Batch).initCapacity(config.allocator, 256),
            .scene_fb = createFB(config.width, config.height, true),
            .ping_fb = createFB(config.width, config.height, false),
            .pong_fb = createFB(config.width, config.height, false),
            .bloom_shader = bloom_shader,
            .vignette_shader = vignette_shader,
            .tonemap_shader = tonemap_shader,
            .fxaa_shader = fxaa_shader,
            .u_src_tex = u_src_tex,
            .u_post_params = u_post_params,
            .u_post_params2 = u_post_params2,
            .passes = .{},
        };
    }

    pub fn deinit(self: *Renderer) void {
        for (self.passes.items) |pass| freePass(self.allocator, pass);
        self.passes.deinit(self.allocator);
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.batches.deinit(self.allocator);
        bgfx.destroyUniform(self.sampler);
        bgfx.destroyUniform(self.u_src_tex);
        bgfx.destroyUniform(self.u_post_params);
        bgfx.destroyUniform(self.u_post_params2);
        bgfx.destroyTexture(self.white_texture);
        bgfx.destroyProgram(self.shader.program_handle);
        bgfx.destroyProgram(self.bloom_shader.program_handle);
        bgfx.destroyProgram(self.vignette_shader.program_handle);
        bgfx.destroyProgram(self.tonemap_shader.program_handle);
        bgfx.destroyProgram(self.fxaa_shader.program_handle);
        bgfx.destroyFrameBuffer(self.scene_fb);
        bgfx.destroyFrameBuffer(self.ping_fb);
        bgfx.destroyFrameBuffer(self.pong_fb);
        bgfx.shutdown();
    }

    pub fn resize(self: *Renderer, width: u32, height: u32) void {
        self.width = width;
        self.height = height;
        bgfx.reset(width, height, bgfx.ResetFlags_None, .Count);
        bgfx.destroyFrameBuffer(self.scene_fb);
        bgfx.destroyFrameBuffer(self.ping_fb);
        bgfx.destroyFrameBuffer(self.pong_fb);
        self.scene_fb = createFB(width, height, true);
        self.ping_fb = createFB(width, height, false);
        self.pong_fb = createFB(width, height, false);
        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);
        self.proj3d = buildProj(self.fov_y, w / h, self.near, self.far);
    }
    /// Add a built-in pass. Returns a handle for later removal/toggling.
    pub fn addPass(self: *Renderer, config: PassConfig) !PassHandle {
        if (self.passes.items.len >= MAX_POST_PASSES) return error.TooManyPasses;
        const handle: PassHandle = @intCast(self.passes.items.len);
        try self.passes.append(self.allocator, .{ .config = config });
        return handle;
    }

    /// Add a custom pass. Uniforms are deep-copied into the renderer's allocator.
    pub fn addCustomPass(self: *Renderer, shader: ShaderProgram, uniforms: []const UniformValue) !PassHandle {
        if (self.passes.items.len >= MAX_POST_PASSES) return error.TooManyPasses;
        const owned = try self.allocator.alloc(UniformValue, uniforms.len);
        for (uniforms, 0..) |u, i| {
            owned[i] = .{
                .name = try self.allocator.dupe(u8, u.name),
                .value = u.value,
            };
        }
        const handle: PassHandle = @intCast(self.passes.items.len);
        try self.passes.append(self.allocator, .{
            .config = .{ .custom = .{ .shader = shader, .uniforms = owned } },
        });
        return handle;
    }

    pub fn removePass(self: *Renderer, handle: PassHandle) void {
        if (handle >= self.passes.items.len) return;
        freePass(self.allocator, self.passes.items[handle]);
        _ = self.passes.orderedRemove(handle);
    }

    pub fn clearPasses(self: *Renderer) void {
        for (self.passes.items) |pass| freePass(self.allocator, pass);
        self.passes.clearRetainingCapacity();
    }

    pub fn setPassEnabled(self: *Renderer, handle: PassHandle, enabled: bool) void {
        if (handle < self.passes.items.len) self.passes.items[handle].enabled = enabled;
    }

    pub fn drawText(self: *Renderer, font: anytype, x: f32, y: f32, color: u32, text: []const u8) void {
        const cw = font.charWidth();
        const ch = font.charHeight();
        var cx = x;
        for (text) |char| {
            if (Font.glyphUV(char)) |uv| {
                self.drawRectTexturedUV(cx, y, cw, ch, color, font.texture, uv.u0, uv.v0, uv.u1, uv.v1);
            }
            cx += cw;
        }
    }

    pub fn drawTextCentered(self: *Renderer, font: anytype, center_x: f32, y: f32, color: u32, text: []const u8) void {
        const w = font.measureText(text);
        self.drawText(font, center_x - w * 0.5, y, color, text);
    }

    pub fn drawRectTexturedUV(self: *Renderer, x: f32, y: f32, w: f32, h: f32, color: u32, texture: bgfx.TextureHandle, uu0: f32, v0: f32, uu1: f32, v1: f32) void {
        self.quad2d(texture, mkv(x, y, 0, color, uu0, v0), mkv(x + w, y, 0, color, uu1, v0), mkv(x + w, y + h, 0, color, uu1, v1), mkv(x, y + h, 0, color, uu0, v1));
    }

    pub fn setCamera(self: *Renderer, view: math.Mat4x4) void {
        self.view3d = view;
    }

    pub fn setProjection(self: *Renderer, fov_y_radians: f32, near: f32, far: f32) void {
        self.fov_y = fov_y_radians;
        self.near = near;
        self.far = far;
        const w: f32 = @floatFromInt(self.width);
        const h: f32 = @floatFromInt(self.height);
        self.proj3d = buildProj(fov_y_radians, w / h, near, far);
    }

    pub fn beginFrame(self: *Renderer) void {
        self.vertices.clearRetainingCapacity();
        self.indices.clearRetainingCapacity();
        self.batches.clearRetainingCapacity();

        const w: f32 = @floatFromInt(self.width);
        const h: f32 = @floatFromInt(self.height);
        const wi: u16 = @intCast(self.width);
        const hi: u16 = @intCast(self.height);

        // View 0: 3D scene
        bgfx.setViewRect(VIEW_SCENE, 0, 0, wi, hi);
        bgfx.setViewClear(VIEW_SCENE, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030FF, 1.0, 0);
        bgfx.setViewFrameBuffer(VIEW_SCENE, if (self.passes.items.len > 0) self.scene_fb else .{ .idx = 0xFFFF });
        bgfx.touch(VIEW_SCENE);

        // View 1: 2D HUD — always backbuffer
        const proj2d = orthoPixels(w, h);
        bgfx.setViewRect(VIEW_HUD, 0, 0, wi, hi);
        bgfx.setViewClear(VIEW_HUD, bgfx.ClearFlags_None, 0, 1.0, 0);
        bgfx.setViewTransform(VIEW_HUD, &math.Mat4x4.ident.v, &proj2d.v);
        bgfx.setViewFrameBuffer(VIEW_HUD, .{ .idx = 0xFFFF });
        bgfx.touch(VIEW_HUD);
    }

    pub fn endFrame(self: *Renderer) void {
        self.flush();
        self.runPostStack();
        self.reorderViews();
        _ = bgfx.frame(0);
    }

    pub fn drawBox(self: *Renderer, transform: Transform, size: math.Vec3, color: u32) void {
        self.drawBoxMatrix(transform.toMatrix(), size, color);
    }

    pub fn drawBoxMatrix(self: *Renderer, transform: math.Mat4x4, size: math.Vec3, color: u32) void {
        const hx = size.x() * 0.5;
        const hy = size.y() * 0.5;
        const hz = size.z() * 0.5;
        const faces = [6][4]Vertex{
            .{ mkv(-hx, -hy, hz, color, 0, 0), mkv(hx, -hy, hz, color, 1, 0), mkv(hx, hy, hz, color, 1, 1), mkv(-hx, hy, hz, color, 0, 1) },
            .{ mkv(hx, -hy, -hz, color, 0, 0), mkv(-hx, -hy, -hz, color, 1, 0), mkv(-hx, hy, -hz, color, 1, 1), mkv(hx, hy, -hz, color, 0, 1) },
            .{ mkv(hx, -hy, hz, color, 0, 0), mkv(hx, -hy, -hz, color, 1, 0), mkv(hx, hy, -hz, color, 1, 1), mkv(hx, hy, hz, color, 0, 1) },
            .{ mkv(-hx, -hy, -hz, color, 0, 0), mkv(-hx, -hy, hz, color, 1, 0), mkv(-hx, hy, hz, color, 1, 1), mkv(-hx, hy, -hz, color, 0, 1) },
            .{ mkv(-hx, hy, hz, color, 0, 0), mkv(hx, hy, hz, color, 1, 0), mkv(hx, hy, -hz, color, 1, 1), mkv(-hx, hy, -hz, color, 0, 1) },
            .{ mkv(-hx, -hy, -hz, color, 0, 0), mkv(hx, -hy, -hz, color, 1, 0), mkv(hx, -hy, hz, color, 1, 1), mkv(-hx, -hy, hz, color, 0, 1) },
        };
        for (faces) |f| self.quad3d(transform, self.white_texture, f[0], f[1], f[2], f[3]);
    }

    pub fn drawQuad(self: *Renderer, transform: Transform, size: math.Vec2, color: u32) void {
        self.drawQuadMatrix(transform.toMatrix(), size, color, self.white_texture);
    }
    pub fn drawQuadTextured(self: *Renderer, transform: Transform, size: math.Vec2, color: u32, texture: bgfx.TextureHandle) void {
        self.drawQuadMatrix(transform.toMatrix(), size, color, texture);
    }
    pub fn drawQuadMatrix(self: *Renderer, transform: math.Mat4x4, size: math.Vec2, color: u32, texture: bgfx.TextureHandle) void {
        const hw = size.x() * 0.5;
        const hh = size.y() * 0.5;
        self.quad3d(transform, texture, mkv(-hw, -hh, 0, color, 0, 0), mkv(hw, -hh, 0, color, 1, 0), mkv(hw, hh, 0, color, 1, 1), mkv(-hw, hh, 0, color, 0, 1));
    }

    pub fn drawSphere(self: *Renderer, transform: Transform, radius: f32, color: u32) void {
        const stacks: u32 = 8;
        const slices: u32 = 12;
        const sf: f32 = @floatFromInt(stacks);
        const sl: f32 = @floatFromInt(slices);
        const mat = transform.toMatrix();
        for (0..stacks) |stack| {
            for (0..slices) |slice| {
                const phi0 = std.math.pi * @as(f32, @floatFromInt(stack)) / sf - std.math.pi * 0.5;
                const phi1 = std.math.pi * @as(f32, @floatFromInt(stack + 1)) / sf - std.math.pi * 0.5;
                const theta0 = 2.0 * std.math.pi * @as(f32, @floatFromInt(slice)) / sl;
                const theta1 = 2.0 * std.math.pi * @as(f32, @floatFromInt(slice + 1)) / sl;
                const p = [4]math.Vec3{
                    spherePt(radius, theta0, phi0), spherePt(radius, theta1, phi0),
                    spherePt(radius, theta1, phi1), spherePt(radius, theta0, phi1),
                };
                self.quad3d(mat, self.white_texture, mkv(p[0].x(), p[0].y(), p[0].z(), color, 0, 0), mkv(p[1].x(), p[1].y(), p[1].z(), color, 1, 0), mkv(p[2].x(), p[2].y(), p[2].z(), color, 1, 1), mkv(p[3].x(), p[3].y(), p[3].z(), color, 0, 1));
            }
        }
    }

    pub fn drawRect(self: *Renderer, x: f32, y: f32, w: f32, h: f32, color: u32) void {
        self.quad2d(self.white_texture, mkv(x, y, 0, color, 0, 0), mkv(x + w, y, 0, color, 1, 0), mkv(x + w, y + h, 0, color, 1, 1), mkv(x, y + h, 0, color, 0, 1));
    }
    pub fn drawRectTextured(self: *Renderer, x: f32, y: f32, w: f32, h: f32, color: u32, texture: bgfx.TextureHandle) void {
        self.quad2d(texture, mkv(x, y, 0, color, 0, 0), mkv(x + w, y, 0, color, 1, 0), mkv(x + w, y + h, 0, color, 1, 1), mkv(x, y + h, 0, color, 0, 1));
    }
    pub fn drawLine(self: *Renderer, x0: f32, y0: f32, x1: f32, y1: f32, thickness: f32, color: u32) void {
        const dx = x1 - x0;
        const dy = y1 - y0;
        const len = @sqrt(dx * dx + dy * dy);
        if (len == 0) return;
        const nx = -dy / len * thickness * 0.5;
        const ny = dx / len * thickness * 0.5;
        self.quad2d(self.white_texture, mkv(x0 + nx, y0 + ny, 0, color, 0, 0), mkv(x1 + nx, y1 + ny, 0, color, 1, 0), mkv(x1 - nx, y1 - ny, 0, color, 1, 1), mkv(x0 - nx, y0 - ny, 0, color, 0, 1));
    }
    pub fn drawCircle(self: *Renderer, cx: f32, cy: f32, radius: f32, segments: u32, color: u32) void {
        const n: f32 = @floatFromInt(segments);
        for (0..segments) |i| {
            const t0 = std.math.pi * 2.0 * @as(f32, @floatFromInt(i)) / n;
            const t1 = std.math.pi * 2.0 * @as(f32, @floatFromInt(i + 1)) / n;
            self.quad2d(self.white_texture, mkv(cx, cy, 0, color, 0.5, 0.5), mkv(cx + @cos(t0) * radius, cy + @sin(t0) * radius, 0, color, 0, 0), mkv(cx + @cos(t1) * radius, cy + @sin(t1) * radius, 0, color, 1, 0), mkv(cx, cy, 0, color, 0.5, 0.5));
        }
    }

    pub fn createFrameBuffer(_: *Renderer, w: u32, h: u32) bgfx.FrameBufferHandle {
        return createFB(w, h, false);
    }
    pub fn createFrameBufferWithDepth(_: *Renderer, w: u32, h: u32) bgfx.FrameBufferHandle {
        return createFB(w, h, true);
    }
    pub fn destroyFrameBuffer(_: *Renderer, fb: bgfx.FrameBufferHandle) void {
        bgfx.destroyFrameBuffer(fb);
    }
    pub fn getFrameBufferTexture(_: *Renderer, fb: bgfx.FrameBufferHandle) bgfx.TextureHandle {
        return bgfx.getTexture(fb, 0);
    }

    pub fn submitPostPass(
        self: *Renderer,
        view: bgfx.ViewId,
        out_fb: bgfx.FrameBufferHandle,
        shader: ShaderProgram,
        in_tex: bgfx.TextureHandle,
    ) void {
        const wi: u16 = @intCast(self.width);
        const hi: u16 = @intCast(self.height);
        bgfx.setViewRect(view, 0, 0, wi, hi);
        bgfx.setViewFrameBuffer(view, out_fb);
        bgfx.setViewClear(view, bgfx.ClearFlags_None, 0, 1.0, 0);
        self.submitFullscreenQuad(view, shader, in_tex, null, null);
    }

    fn quad3d(self: *Renderer, transform: math.Mat4x4, texture: bgfx.TextureHandle, v0: Vertex, v1: Vertex, v2: Vertex, v3: Vertex) void {
        self.pushQuad(VIEW_SCENE, transform, texture, v0, v1, v2, v3);
    }
    fn quad2d(self: *Renderer, texture: bgfx.TextureHandle, v0: Vertex, v1: Vertex, v2: Vertex, v3: Vertex) void {
        self.pushQuad(VIEW_HUD, math.Mat4x4.ident, texture, v0, v1, v2, v3);
    }

    fn pushQuad(self: *Renderer, view: u8, transform: math.Mat4x4, texture: bgfx.TextureHandle, v0: Vertex, v1: Vertex, v2: Vertex, v3: Vertex) void {
        const base: u16 = @intCast(self.vertices.items.len);
        const vstart: u32 = @intCast(base);
        const istart: u32 = @intCast(self.indices.items.len);

        self.vertices.appendSlice(self.allocator, &.{ v0, v1, v2, v3 }) catch return;
        self.indices.appendSlice(self.allocator, &.{ base, base + 1, base + 2, base + 2, base + 3, base }) catch return;

        if (self.batches.items.len > 0) {
            const last = &self.batches.items[self.batches.items.len - 1];
            if (last.view == view and last.texture.idx == texture.idx and math.Mat4x4.eql(&last.transform, &transform)) {
                last.vertex_count += 4;
                last.index_count += 6;
                return;
            }
        }
        self.batches.append(self.allocator, .{
            .view = view,
            .texture = texture,
            .transform = transform,
            .vertex_start = vstart,
            .vertex_count = 4,
            .index_start = istart,
            .index_count = 6,
        }) catch return;
    }

    fn flush(self: *Renderer) void {
        bgfx.setViewTransform(VIEW_SCENE, &self.view3d.v, &self.proj3d.v);
        if (self.batches.items.len == 0) return;
        const tv = self.vertices.items.len;
        const ti = self.indices.items.len;
        if (tv == 0) return;

        var tvb: bgfx.TransientVertexBuffer = undefined;
        var tib: bgfx.TransientIndexBuffer = undefined;
        if (!bgfx.allocTransientBuffers(&tvb, &self.layout, @intCast(tv), &tib, @intCast(ti), false)) {
            std.log.err("renderer: out of transient buffer space", .{});
            return;
        }
        const dv: [*]Vertex = @ptrCast(@alignCast(tvb.data));
        @memcpy(dv[0..tv], self.vertices.items);
        const di: [*]u16 = @ptrCast(@alignCast(tib.data));
        @memcpy(di[0..ti], self.indices.items);
        for (self.batches.items) |batch| {
            const t = batch.transform.transpose();
            _ = bgfx.setTransform(&t.v, 1);
            bgfx.setTransientVertexBuffer(0, &tvb, batch.vertex_start, batch.vertex_count);
            bgfx.setTransientIndexBuffer(&tib, batch.index_start, batch.index_count);
            bgfx.setTexture(0, self.sampler, batch.texture, std.math.maxInt(u32));
            //const blend_alpha = bgfx.StateFlags_BlendSrcAlpha | (bgfx.StateFlags_BlendInvSrcAlpha << 4);
            const state = if (batch.view == VIEW_SCENE)
                bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess
            else
                bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | (bgfx.StateFlags_BlendSrcAlpha | (bgfx.StateFlags_BlendInvSrcAlpha << 4));
            //const state = if (batch.view == VIEW_SCENE)
            //  bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess
            //else

            //bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_BlendSrcAlpha;
            bgfx.setState(state, 0);

            bgfx.submit(batch.view, self.shader.program_handle, 0, @as(u8, 0xFF));
        }
    }

    fn runPostStack(self: *Renderer) void {
        // Count enabled passes
        var enabled_count: u32 = 0;
        for (self.passes.items) |p| if (p.enabled) {
            enabled_count += 1;
        };
        if (enabled_count == 0) return;

        const wi: u16 = @intCast(self.width);
        const hi: u16 = @intCast(self.height);
        var src_tex = bgfx.getTexture(self.scene_fb, 0);
        var view_id: bgfx.ViewId = VIEW_POST_BASE;
        var pass_idx: u32 = 0;
        var enabled_idx: u32 = 0;

        for (self.passes.items) |pass| {
            if (!pass.enabled) continue;
            enabled_idx += 1;
            const is_last = (enabled_idx == enabled_count);

            // Last pass → backbuffer; others → ping/pong
            const dst_fb: bgfx.FrameBufferHandle =
                if (is_last) .{ .idx = 0xFFFF } else if (pass_idx % 2 == 0) self.ping_fb else self.pong_fb;

            bgfx.setViewRect(view_id, 0, 0, wi, hi);
            bgfx.setViewFrameBuffer(view_id, dst_fb);
            bgfx.setViewClear(view_id, bgfx.ClearFlags_None, 0, 1.0, 0);

            switch (pass.config) {
                .bloom => |cfg| {
                    const p1 = [4]f32{ cfg.threshold, cfg.intensity, cfg.radius, 0 };
                    const p2 = [4]f32{ @as(f32, @floatFromInt(self.width)), @as(f32, @floatFromInt(self.height)), 0, 0 };
                    self.submitFullscreenQuad(view_id, self.bloom_shader, src_tex, &p1, &p2);
                },
                .vignette => |cfg| {
                    const p1 = [4]f32{ cfg.strength, cfg.radius, 0, 0 };
                    self.submitFullscreenQuad(view_id, self.vignette_shader, src_tex, &p1, null);
                },
                .tonemap => |cfg| {
                    const p1 = [4]f32{ cfg.exposure, 0, 0, 0 };
                    self.submitFullscreenQuad(view_id, self.tonemap_shader, src_tex, &p1, null);
                },
                .fxaa => {
                    const p1 = [4]f32{ 1.0 / @as(f32, @floatFromInt(self.width)), 1.0 / @as(f32, @floatFromInt(self.height)), 0, 0 };
                    self.submitFullscreenQuad(view_id, self.fxaa_shader, src_tex, &p1, null);
                },
                .custom => |cfg| {
                    for (cfg.uniforms) |u| {
                        const handle = bgfx.createUniform(
                            @as([*:0]const u8, @ptrCast(u.name.ptr)),
                            .Vec4,
                            1,
                        );
                        switch (u.value) {
                            .vec4 => |v| bgfx.setUniform(handle, &v, 1),
                            .mat4 => |v| bgfx.setUniform(handle, &v, 1),
                        }
                        bgfx.destroyUniform(handle); // <-- add this
                    }
                    self.submitFullscreenQuad(view_id, cfg.shader, src_tex, null, null);

                    //for (cfg.uniforms) |u| {
                    //    const handle = bgfx.createUniform(
                    //        @as([*:0]const u8, @ptrCast(u.name.ptr)),
                    //        .Vec4,
                    //        1,
                    //    );
                    //    switch (u.value) {
                    //        .vec4 => |v| bgfx.setUniform(handle, &v, 1),
                    //        .mat4 => |v| bgfx.setUniform(handle, &v, 1),
                    //    }
                    // }
                    //self.submitFullscreenQuad(view_id, cfg.shader, src_tex, null, null);
                },
            }

            if (!is_last) src_tex = bgfx.getTexture(dst_fb, 0);
            view_id += 1;
            pass_idx += 1;
        }
    }

    fn submitFullscreenQuad(
        self: *Renderer,
        view: bgfx.ViewId,
        shader: ShaderProgram,
        tex: bgfx.TextureHandle,
        params: ?*const [4]f32,
        params2: ?*const [4]f32,
    ) void {
        if (params) |p| bgfx.setUniform(self.u_post_params, p, 1);
        if (params2) |p| bgfx.setUniform(self.u_post_params2, p, 1);
        bgfx.setTexture(0, self.u_src_tex, tex, std.math.maxInt(u32));
        bgfx.setState(bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA, 0);
        bgfx.setVertexCount(3);
        bgfx.submit(view, shader.program_handle, 0, @as(u8, 0xFF));
    }

    fn reorderViews(self: *Renderer) void {
        var order: [MAX_POST_PASSES + 3]bgfx.ViewId = undefined;
        order[0] = VIEW_SCENE;
        var n: u16 = 1;
        var ei: bgfx.ViewId = 0;
        for (self.passes.items) |pass| {
            if (!pass.enabled) continue;
            order[n] = VIEW_POST_BASE + ei;
            n += 1;
            ei += 1;
        }
        order[n] = VIEW_HUD;
        n += 1;
        bgfx.setViewOrder(0, n, &order);
    }

    fn orthoPixels(w: f32, h: f32) math.Mat4x4 {
        const m = [16]f32{
            2.0 / w, 0,        0, 0,
            0,       -2.0 / h, 0, 0,
            0,       0,        1, 0,
            -1.0,    1.0,      0, 1,
        };
        return @bitCast(m);
    }

    fn buildProj(fov_y: f32, aspect: f32, near: f32, far: f32) math.Mat4x4 {
        const f = 1.0 / @tan(fov_y * 0.5);
        var m = math.Mat4x4.ident;
        m.v[0].v[0] = f / aspect;
        m.v[1].v[1] = f;
        m.v[2].v[2] = far / (far - near);
        m.v[2].v[3] = 1.0;
        m.v[3].v[2] = -(far * near) / (far - near);
        m.v[3].v[3] = 0.0;
        return m;
    }
};

fn freePass(allocator: Allocator, pass: Pass) void {
    if (pass.config == .custom) {
        for (pass.config.custom.uniforms) |u| allocator.free(u.name);
        allocator.free(pass.config.custom.uniforms);
    }
}

fn createFB(w: u32, h: u32, with_depth: bool) bgfx.FrameBufferHandle {
    if (with_depth) {
        const textures = [2]bgfx.TextureHandle{
            bgfx.createTexture2D(@intCast(w), @intCast(h), false, 1, .RGBA16F, bgfx.TextureFlags_Rt | bgfx.SamplerFlags_UvwClamp, null, 0),
            bgfx.createTexture2D(@intCast(w), @intCast(h), false, 1, .D24S8, bgfx.TextureFlags_Rt, null, 0),
        };
        return bgfx.createFrameBufferFromHandles(2, &textures, true);
    } else {
        return bgfx.createFrameBuffer(@intCast(w), @intCast(h), .RGBA16F, bgfx.TextureFlags_Rt | bgfx.SamplerFlags_UvwClamp);
    }
}

inline fn mkv(x: f32, y: f32, z: f32, color: u32, u: f32, vt: f32) Vertex {
    return .{ .x = x, .y = y, .z = z, .color = color, .u = u, .v = vt };
}

fn spherePt(radius: f32, theta: f32, phi: f32) math.Vec3 {
    return math.Vec3.init(
        radius * @cos(phi) * @cos(theta),
        radius * @sin(phi),
        radius * @cos(phi) * @sin(theta),
    );
}
