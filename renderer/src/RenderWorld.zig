/// High-level renderer entry point.
/// Manages the bgfx context, cameras, lights, draw lists, 2D batch, and post-processing.
///
/// Quick-start (rookies):
///   var rw = try RenderWorld.init(allocator, .{ .nwh = ..., .width = 1280, .height = 720 });
///   rw.setCamera3D(Camera.fps(...));
///   rw.addDirectionalLight(.{ .x=0,..,.z=-1 }, .{.x=1,.y=1,.z=1}, 1.0);
///   while (running) {
///       rw.beginFrame();
///       rw.drawMesh(&mesh, Material.unlit(.{.x=1,...}), Mat4.identity());
///       rw.drawRect(.{ .x=10,.y=10,.width=200,.height=40 }, .{.x=1,.y=1,.z=0,.w=1});
///       rw.endFrame();
///   }
///
/// Power users can reach into getEncoder(), getView(), postProcess etc.
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");

const Context = @import("Context.zig");
const View = @import("View.zig");
const Camera = @import("Camera.zig");
const Material = @import("Material.zig");
const Mesh = @import("Mesh.zig");
const DrawList = @import("DrawList.zig");
const Batch2D = @import("Batch2D.zig");
const PostProcess = @import("PostProcess.zig");
const Framebuffer = @import("Framebuffer.zig");
const UniformStore = @import("UniformStore.zig");
const DrawEncoder = @import("DrawEncoder.zig");
const ShaderProgram = @import("ShaderProgram.zig");
const light_mod = @import("lights.zig");
const env_map = @import("env_map.zig");
const shaders = @import("shader_module");

const RenderWorld = @This();

// ---- Constants --------------------------------------------------------------

/// bgfx view reserved for the 3D scene.
pub const VIEW_3D: u16 = 0;

/// 2D view (fullscreen UI). No depth test, alpha blend.
pub const VIEW_2D: u16 = 1;

/// Post-processing passes output here (view 2, no framebuffer = backbuffer/screen).
pub const VIEW_POST: u16 = 2;

/// Post-processing passes start here (for multi-pass chains).
pub const VIEW_POST_BASE: u16 = 3;

pub const MAX_VIEWS: u16 = 32;
pub const VIEW_SHADOW: u16 = 30;
pub const MAX_LIGHTS = light_mod.MAX_LIGHTS;

// ---- Programs (cached shader programs) --------------------------------------

const Programs = struct {
    unlit: ShaderProgram,
    blinn_phong: ShaderProgram,
    pbr: ShaderProgram,
    sprite: ShaderProgram,
    blit: ShaderProgram,
    fog: ShaderProgram,

    fn init() !Programs {
        const rt = bgfx.getRendererType();
        std.log.info("[renderer] Initializing unlit program...", .{});
        const unlit = try ShaderProgram.initFromMem(shaders.vs_unlit.getShaderForRenderer(rt), shaders.fs_unlit.getShaderForRenderer(rt));
        std.log.info("[renderer] Initializing blinn_phong program...", .{});
        const blinn_phong = try ShaderProgram.initFromMem(shaders.vs_blinn_phong.getShaderForRenderer(rt), shaders.fs_blinn_phong.getShaderForRenderer(rt));
        std.log.info("[renderer] Initializing pbr program...", .{});
        const pbr = try ShaderProgram.initFromMem(shaders.vs_pbr.getShaderForRenderer(rt), shaders.fs_pbr.getShaderForRenderer(rt));
        std.log.info("[renderer] Initializing sprite program...", .{});
        const sprite = try ShaderProgram.initFromMem(shaders.vs_sprite.getShaderForRenderer(rt), shaders.fs_sprite.getShaderForRenderer(rt));
        std.log.info("[renderer] Initializing blit program...", .{});
        const blit = try ShaderProgram.initFromMem(shaders.vs_fullscreen.getShaderForRenderer(rt), shaders.fs_blit.getShaderForRenderer(rt));
        std.log.info("[renderer] Initializing fog program...", .{});
        const fog = try ShaderProgram.initFromMem(shaders.vs_fullscreen.getShaderForRenderer(rt), shaders.fs_fog.getShaderForRenderer(rt));

        return .{
            .unlit = unlit,
            .blinn_phong = blinn_phong,
            .pbr = pbr,
            .sprite = sprite,
            .blit = blit,
            .fog = fog,
        };
    }

    fn deinit(self: *Programs) void {
        self.unlit.deinit();
        self.blinn_phong.deinit();
        self.pbr.deinit();
        self.sprite.deinit();
        self.blit.deinit();
        self.fog.deinit();
    }
};

// ---- Config -----------------------------------------------------------------

pub const Config = struct {
    /// Native window handle (platform specific — from rgfw Window.getNativePtr()).
    nwh: ?*anyopaque,
    /// Native display handle (platform specific — from rgfw Window.getNativeNdt()).
    ndt: ?*anyopaque = null,
    width: u32,
    height: u32,
    debug: bool = false,
    /// bgfx backend. Defaults to platform-native (Count = auto-select).
    renderer: bgfx.RendererType = bgfx.RendererType.Count,
    /// Enable post-processing (allocates an off-screen framebuffer for the 3D view).
    post_process: bool = false,
    /// Antialiasing mode. Default is none.
    aa_mode: Context.AaMode = .none,
};

// ---- Fields -----------------------------------------------------------------

allocator: std.mem.Allocator,
context: Context,
uniforms: UniformStore,
programs: Programs,
draw_3d: DrawList,
batch_2d: Batch2D,

camera_3d: Camera,
camera_2d: Camera,

lights: [MAX_LIGHTS]light_mod.Light,
num_lights: u32,

width: u32,
height: u32,

/// If post_process is enabled, the 3D scene renders here before being blitted to screen.
scene_fb: ?Framebuffer,

/// External post-processing chain. Set via setPostProcess().
post_process: ?*PostProcess = null,

environment: ?*env_map.Environment = null,

shadow_map: ?Framebuffer = null,
shadow_light_idx: u32 = 0,
shadow_mat: math.Mat4 = math.Mat4.identity(),
fog_color: math.Vec3 = .{ .x = 0.6, .y = 0.65, .z = 0.75 },
fog_density: f32 = 0.01,
fog_start: f32 = 50.0,
fog_end: f32 = 200.0,

// ---- Lifecycle --------------------------------------------------------------

pub fn init(allocator: std.mem.Allocator, config: Config) !*RenderWorld {
    const self = try allocator.create(RenderWorld);
    errdefer allocator.destroy(self);

    // Init bgfx
    const ctx = try Context.init(.{
        .allocator = allocator,
        .nwh = config.nwh,
        .ndt = config.ndt,
        .width = config.width,
        .height = config.height,
        .debug = config.debug,
        .renderer = config.renderer,
        .aa_mode = config.aa_mode,
    });

    const progs = try Programs.init();
    const uniforms = UniformStore.init(allocator);
    const draw_3d = DrawList.init(allocator);
    const batch_2d = try Batch2D.init(allocator, progs.sprite);

    // Default cameras
    const aspect = @as(f32, @floatFromInt(config.width)) / @as(f32, @floatFromInt(config.height));
    const cam3d = Camera.fps(
        math.Vec3.new(0, 3, -5),
        math.Vec3.zero(),
        aspect,
    );
    const cam2d = Camera.ui(
        @floatFromInt(config.width),
        @floatFromInt(config.height),
    );

    // Optional scene framebuffer for post-processing
    var scene_fb: ?Framebuffer = null;
    if (config.post_process) {
        scene_fb = try Framebuffer.init(allocator, .{
            .attachments = &.{
                .{ .color = .{ .format = .RGBA16F } },
                .{ .depth = .{ .format = .D24S8 } },
            },
            .width = config.width,
            .height = config.height,
        });
    }

    const shadow_fb = try Framebuffer.init(allocator, .{
        .attachments = &.{
            .{ .color = .{ .format = .RGBA16F } },
            .{ .depth = .{ .format = .D24S8 } },
        },
        .width = 2048,
        .height = 2048,
    });

    self.* = .{
        .allocator = allocator,
        .context = ctx,
        .uniforms = uniforms,
        .programs = progs,
        .draw_3d = draw_3d,
        .batch_2d = batch_2d,
        .camera_3d = cam3d,
        .camera_2d = cam2d,
        .lights = [_]light_mod.Light{undefined} ** MAX_LIGHTS,
        .num_lights = 0,
        .width = config.width,
        .height = config.height,
        .scene_fb = scene_fb,
        .shadow_map = shadow_fb,
    };

    return self;
}

pub fn deinit(self: *RenderWorld) void {
    if (self.scene_fb) |*fb| fb.deinit();
    if (self.shadow_map) |*fb| fb.deinit();
    self.batch_2d.deinit();
    self.draw_3d.deinit();
    self.programs.deinit();
    self.uniforms.deinit();
    self.context.deinit();
    self.allocator.destroy(self);
}

// ---- Simple high-level API --------------------------------------------------

pub fn setCamera3D(self: *RenderWorld, cam: Camera) void {
    self.camera_3d = cam;
}
pub fn setCamera2D(self: *RenderWorld, cam: Camera) void {
    self.camera_2d = cam;
}

/// Add a light of any type. Silently ignored if MAX_LIGHTS is reached.
pub fn addLight(self: *RenderWorld, light: light_mod.Light) void {
    if (self.num_lights >= MAX_LIGHTS) return;
    self.lights[self.num_lights] = light;
    self.num_lights += 1;
}

pub fn addDirectionalLight(self: *RenderWorld, dir: math.Vec3, color: math.Vec3, intensity: f32) void {
    self.addLight(light_mod.Light.directional(dir, color, intensity));
}

pub fn addPointLight(self: *RenderWorld, pos: math.Vec3, color: math.Vec3, intensity: f32, radius: f32) void {
    self.addLight(light_mod.Light.point(pos, color, intensity, radius));
}

pub fn addSpotLight(self: *RenderWorld, pos: math.Vec3, dir: math.Vec3, color: math.Vec3, intensity: f32, inner_angle: f32, outer_angle: f32, radius: f32) void {
    self.addLight(light_mod.Light.spot(pos, dir, color, intensity, inner_angle, outer_angle, radius));
}

/// Remove all lights.
pub fn clearLights(self: *RenderWorld) void {
    self.num_lights = 0;
}

/// Queue a 3D mesh draw. Call between beginFrame()/endFrame().
pub fn drawMesh(self: *RenderWorld, mesh: *const Mesh, material: Material, transform: math.Mat4) void {
    self.draw_3d.push(mesh, material, transform);
}

/// Queue a 2D textured sprite quad. Coordinates are in screen-space pixels (top-left origin).
pub fn drawSprite(
    self: *RenderWorld,
    dest: math.Rect,
    uv: math.Rect,
    color: math.Vec4,
    texture: ?*const Framebuffer,
) void {
    const tex_handle: ?bgfx.TextureHandle = if (texture) |fb| fb.colorTexture() else null;
    self.batch_2d.pushQuad(VIEW_2D, &self.uniforms, dest, uv, color, tex_handle);
}

/// Queue a solid 2D colored rectangle.
pub fn drawRect(self: *RenderWorld, rect: math.Rect, color: math.Vec4) void {
    self.batch_2d.pushRect(VIEW_2D, &self.uniforms, rect, color);
}

/// Resize the renderer (call on window resize events).
pub fn resize(self: *RenderWorld, width: u32, height: u32) void {
    self.width = width;
    self.height = height;
    self.context.resize(width, height);

    if (self.camera_2d.kind == .ortho) {
        self.camera_2d.kind.ortho.setSize(@floatFromInt(width), @floatFromInt(height));
    }

    if (self.scene_fb) |*fb| {
        fb.resize(.{
            .attachments = &.{
                .{ .color = .{ .format = .RGBA16F } },
                .{ .depth = .{ .format = .D24S8 } },
            },
            .width = width,
            .height = height,
        }) catch {};
    }
}

/// Change antialiasing mode at runtime.
pub fn setAaMode(self: *RenderWorld, mode: Context.AaMode) void {
    self.context.setAaMode(mode);
}

/// Set HDR environment map for IBL. Pass null to disable.
pub fn setEnvironment(self: *RenderWorld, env: ?*env_map.Environment) void {
    self.environment = env;
}

/// Set the post-processing chain to run after each frame.
/// The PostProcess is owned by the caller and must remain valid until replaced or RenderWorld is deinitialized.
/// To clear post-processing, pass null.
pub fn setPostProcess(self: *RenderWorld, post: ?*PostProcess) void {
    self.post_process = post;
}

/// Get the scene color texture for use in post-processing passes.
/// Only valid if post_processing was enabled in config.
pub fn getSceneTexture(self: *RenderWorld) ?bgfx.TextureHandle {
    if (self.scene_fb) |fb| {
        return fb.colorTexture();
    }
    return null;
}

/// Get the scene depth texture for use in post-processing passes (e.g. depth-based fog).
/// Only valid if post_processing was enabled in config.
pub fn getDepthTexture(self: *RenderWorld) ?bgfx.TextureHandle {
    if (self.scene_fb) |fb| {
        return fb.depthTexture();
    }
    return null;
}

/// Get the built-in blit shader for post-processing.
/// Use with PostProcess to blit the scene to screen.
pub fn getBlitShader(self: *RenderWorld) ShaderProgram {
    _ = self;
    const rt = bgfx.getRendererType();
    return ShaderProgram.initFromMem(
        shaders.vs_fullscreen.getShaderForRenderer(rt),
        shaders.fs_blit.getShaderForRenderer(rt),
    ) catch unreachable;
}

/// Get the built-in fog shader for post-processing.
pub fn getFogShader(self: *RenderWorld) ShaderProgram {
    _ = self;
    const rt = bgfx.getRendererType();
    return ShaderProgram.initFromMem(
        shaders.vs_fullscreen.getShaderForRenderer(rt),
        shaders.fs_fog.getShaderForRenderer(rt),
    ) catch unreachable;
}

pub const ShadowConfig = struct {
    light_index: u32 = 0,
    bias: f32 = 0.001,
    cascade_size: f32 = 100.0,
};

pub fn setShadowLight(self: *RenderWorld, light_index: u32) void {
    self.shadow_light_idx = light_index;
}

pub fn setFog(self: *RenderWorld, color: math.Vec3, density: f32, start: f32, end: f32) void {
    self.fog_color = color;
    self.fog_density = density;
    self.fog_start = start;
    self.fog_end = end;

    const h_fog_params = self.uniforms.getOrCreate("u_fogParams", bgfx.UniformType.Vec4, 1);
    const h_fog_color = self.uniforms.getOrCreate("u_fogColor", bgfx.UniformType.Vec4, 1);
    const fog_params = math.Vec4{ .x = start, .y = end, .z = density, .w = 0 };
    const fog_color_vec = color.toVec4(1.0);
    bgfx.setUniform(h_fog_params, &fog_params, 1);
    bgfx.setUniform(h_fog_color, &fog_color_vec, 1);
}

// ---- Frame lifecycle --------------------------------------------------------

/// Call at the start of each frame. Clears draw lists, sets up views.
pub fn beginFrame(self: *RenderWorld) void {
    self.draw_3d.clear();
    self.batch_2d.begin();

    renderShadowPass(self);

    // -- 3D view setup
    const view3 = VIEW_3D;
    const view_mat = self.camera_3d.viewMatrix();
    const proj_mat = self.camera_3d.projMatrix();
    bgfx.setViewTransform(view3, &view_mat.m, &proj_mat.m);
    bgfx.setViewRect(view3, 0, 0, @intCast(self.width), @intCast(self.height));
    bgfx.setViewClear(view3, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303040ff, 1.0, 0);
    if (self.scene_fb) |*fb| {
        bgfx.setViewFrameBuffer(view3, fb.handle);
    }

    // -- 2D view setup (renders on top of 3D, no depth test)
    const view2 = VIEW_2D;
    const v2_view = self.camera_2d.viewMatrix();
    const v2_proj = self.camera_2d.projMatrix();
    bgfx.setViewTransform(view2, &v2_view.m, &v2_proj.m);
    bgfx.setViewRect(view2, 0, 0, @intCast(self.width), @intCast(self.height));
    bgfx.setViewClear(view2, bgfx.ClearFlags_None, 0, 1.0, 0);

    // Touch both views — ensures they are rendered even if draw list is empty
    bgfx.touch(VIEW_3D);
    bgfx.touch(VIEW_2D);
}

/// Call at the end of each frame. Flushes draws, runs post-process, advances bgfx frame.
pub fn endFrame(self: *RenderWorld) void {
    self.flush3D();
    self.batch_2d.flush(VIEW_2D, &self.uniforms);
    if (self.post_process) |post| {
        if (post.passes.items.len > 0) {
            post.run(&self.uniforms, self.width, self.height);
        } else if (self.scene_fb) |_| {
            self.blitSceneToScreen();
        }
    }
    _ = bgfx.frame(bgfx.FrameFlags_None);
}

/// Blit scene framebuffer to screen. Called automatically if post-processing is enabled but no chain is set.
pub fn blitSceneToScreen(self: *RenderWorld) void {
    if (self.scene_fb == null) return;

    const enc = DrawEncoder.init(VIEW_2D);
    bgfx.setViewClear(VIEW_2D, 0, 0, 0, 1.0);
    bgfx.setViewRect(VIEW_2D, 0, 0, @intCast(self.width), @intCast(self.height));
    bgfx.setViewTransform(VIEW_2D, null, null);

    const h_tex = self.uniforms.getOrCreate("s_texColor", bgfx.UniformType.Sampler, 1);
    enc.setTexture(0, h_tex, self.scene_fb.?.colorTexture(), 0);

    enc.setStateDefault();
    enc.submit(self.programs.blit, 0);
}

// ---- Low-level power-user API -----------------------------------------------

/// Get a DrawEncoder bound to a specific view. Use for raw bgfx calls.
pub fn getEncoder(_: *RenderWorld, view_id: u16) DrawEncoder {
    return DrawEncoder.init(view_id);
}

/// Access the raw draw list for 3D (e.g. to push custom sorting).
pub fn getDrawList3D(self: *RenderWorld) *DrawList {
    return &self.draw_3d;
}

/// Access the 2D batch directly.
pub fn getBatch2D(self: *RenderWorld) *Batch2D {
    return &self.batch_2d;
}

/// Access the post-process chain to add or remove passes.
pub fn getPostProcess(self: *RenderWorld) *?PostProcess {
    return &self.post_process;
}

/// Access the uniform store to fetch/create handles for custom shaders.
pub fn getUniforms(self: *RenderWorld) *UniformStore {
    return &self.uniforms;
}

/// Returns the scene framebuffer (if post_process was enabled in config).
pub fn getSceneFramebuffer(self: *RenderWorld) ?*Framebuffer {
    if (self.scene_fb) |*fb| return fb;
    return null;
}

// ---- Internal flush ---------------------------------------------------------

fn renderShadowPass(self: *RenderWorld) void {
    if (self.shadow_map == null) return;
    if (self.num_lights == 0) return;

    const light_idx = self.shadow_light_idx;
    if (light_idx >= self.num_lights) return;

    const light = self.lights[light_idx];
    if (light != .dir) return;

    const dir_light = light.dir;
    const light_dir = dir_light.direction;

    const light_pos = math.Vec3.scale(light_dir, -50.0);
    const target = math.Vec3.zero();
    const up = math.Vec3.new(0.0, 1.0, 0.0);

    const light_view = math.Mat4.lookAtRh(light_pos, target, up);
    const light_proj = math.Mat4.orthographic(100.0, 100.0, 0.1, 200.0);

    self.shadow_mat = math.Mat4.mul(light_proj, light_view);

    const shadow_fb = self.shadow_map.?;
    bgfx.setViewFrameBuffer(VIEW_SHADOW, shadow_fb.handle);
    bgfx.setViewTransform(VIEW_SHADOW, &light_view.m, &light_proj.m);
    bgfx.setViewRect(VIEW_SHADOW, 0, 0, 2048, 2048);
    bgfx.setViewClear(VIEW_SHADOW, bgfx.ClearFlags_Depth, 0, 1.0, 0);

    const shadow_enc = DrawEncoder.init(VIEW_SHADOW);

    for (self.draw_3d.commands.items) |*cmd| {
        shadow_enc.setTransform(&cmd.transform);

        const prog = switch (cmd.material.kind) {
            .unlit => self.programs.unlit,
            .blinn_phong => self.programs.blinn_phong,
            .pbr => self.programs.pbr,
            .custom => continue,
        };

        switch (cmd.mesh.buffers) {
            .static => |b| {
                shadow_enc.setVertexBuffer(b.vb, 0, cmd.mesh.vertex_count);
                shadow_enc.setIndexBuffer(b.ib, 0, cmd.mesh.index_count);
            },
            .dynamic => |b| {
                shadow_enc.setDynamicVertexBuffer(b.vb, 0, cmd.mesh.vertex_count);
                shadow_enc.setDynamicIndexBuffer(b.ib, 0, cmd.mesh.index_count);
            },
        }

        shadow_enc.setStateFlags(bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess);
        shadow_enc.submit(prog, 0);
    }
}

fn flush3D(self: *RenderWorld) void {
    if (self.draw_3d.len() == 0) return;

    // Sort opaque front-to-back for depth occlusion
    if (self.camera_3d.kind == .perspective) {
        self.draw_3d.sortOpaque(self.camera_3d.kind.perspective.position);
    }

    // Upload light uniforms once per frame (packed as 4 vec4s per light)
    var light_data: [MAX_LIGHTS * 4]math.Vec4 = [_]math.Vec4{math.Vec4.zero()} ** (MAX_LIGHTS * 4);

    for (0..self.num_lights) |i| {
        const light = self.lights[i];
        const pl = light_mod.PackedLight.fromUnion(light);
        const base = i * 4;
        light_data[base + 0] = pl.position.toVec4(0.0);
        light_data[base + 1] = pl.direction.toVec4(0.0);
        light_data[base + 2] = .{
            .x = pl.color.x,
            .y = pl.color.y,
            .z = pl.color.z,
            .w = pl.intensity,
        };
        light_data[base + 3] = .{
            .x = pl.light_type,
            .y = pl.params.x,
            .z = pl.params.y,
            .w = 0,
        };
    }
    const light_params = math.Vec4{ .x = @floatFromInt(self.num_lights), .y = 0, .z = 0, .w = 0 };

    const h_lights = self.uniforms.getOrCreate("u_lights", bgfx.UniformType.Vec4, MAX_LIGHTS * 4);
    const h_lpar = self.uniforms.vec4("u_lightParams");

    bgfx.setUniform(h_lights, &light_data, @intCast(MAX_LIGHTS * 4));
    bgfx.setUniform(h_lpar, &light_params, 1);

    // Flush each draw command
    const enc = DrawEncoder.init(VIEW_3D);

    if (self.environment) |env| {
        const h_irradiance = self.uniforms.getOrCreate("s_irradiance", bgfx.UniformType.Sampler, 1);
        const h_prefiltered = self.uniforms.getOrCreate("s_prefiltered", bgfx.UniformType.Sampler, 1);
        const h_brdf_lut = self.uniforms.getOrCreate("s_brdfLut", bgfx.UniformType.Sampler, 1);
        const h_env_intensity = self.uniforms.vec4("u_envIntensity");

        const env_intensity = math.Vec4{
            .x = env.env_map.intensity,
            .y = env.env_map.intensity,
            .z = env.env_map.intensity,
            .w = if (env.env_map.valid) 1.0 else 0.0,
        };

        enc.setTexture(10, h_irradiance, env.env_map.irradiance_map, 0);
        enc.setTexture(11, h_prefiltered, env.env_map.prefiltered_map, 0);
        enc.setTexture(12, h_brdf_lut, env.env_map.brdf_lut, 0);
        bgfx.setUniform(h_env_intensity, &env_intensity, 1);
    }

    if (self.shadow_map) |shadow_fb| {
        const h_shadow_map = self.uniforms.getOrCreate("s_shadowMap", bgfx.UniformType.Sampler, 1);
        const h_light_matrix = self.uniforms.getOrCreate("u_lightMatrix", bgfx.UniformType.Mat4, 1);
        enc.setTexture(3, h_shadow_map, shadow_fb.depthTexture(), 0);
        bgfx.setUniform(h_light_matrix, &self.shadow_mat.m, 1);
    }

    for (self.draw_3d.commands.items) |*cmd| {
        enc.setTransform(&cmd.transform);

        // Choose shader based on material kind
        const prog = switch (cmd.material.kind) {
            .unlit => self.programs.unlit,
            .blinn_phong => self.programs.blinn_phong,
            .pbr => self.programs.pbr,
            .custom => |m| blk: {
                m.bind_fn(enc, &self.uniforms);
                break :blk self.programs.unlit; // custom materials set their own program elsewhere
            },
        };

        cmd.material.bind(enc, &self.uniforms);

        switch (cmd.mesh.buffers) {
            .static => |b| {
                enc.setVertexBuffer(b.vb, 0, cmd.mesh.vertex_count);
                enc.setIndexBuffer(b.ib, 0, cmd.mesh.index_count);
            },
            .dynamic => |b| {
                enc.setDynamicVertexBuffer(b.vb, 0, cmd.mesh.vertex_count);
                enc.setDynamicIndexBuffer(b.ib, 0, cmd.mesh.index_count);
            },
        }

        enc.setStateDefault();
        enc.submit(prog, 0);
    }
}
