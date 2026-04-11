/// Post-Processing Pipeline
/// Provides a simple interface for rendering post-processing effects.
///
/// Usage:
///   var post = try PostProcessor.init(allocator, &renderer, width, height);
///   defer post.deinit();
///
///   // Configure effects
///   try post.setExposure(1.0);
///   try post.setVignette(0.5);
///
///   // In render loop:
///   post.beginScenePass(0);           // Scene renders to framebuffer
///   // ... render your scene ...
///   post.endScenePass();              // Post-process to screen
///
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const resources = @import("resources_new.zig");
const material = @import("material_new.zig");

pub const PostProcessor = struct {
    allocator: std.mem.Allocator,
    res: *resources.ResourcePool,
    scene_fb: resources.FramebufferHandle,
    scene_tex: resources.TextureHandle,
    post_mesh: resources.MeshHandle,
    post_mat: material.Material,
    screen_view_id: u8,
    width: u16,
    height: u16,
    exposure: f32,
    vignette_strength: f32,

    const Self = @This();

    /// Initialize a post-processor with the given dimensions
    pub fn init(
        allocator: std.mem.Allocator,
        renderer: *resources.ResourcePool,
        width: u16,
        height: u16,
        screen_view_id: u8,
    ) !Self {
        const backend = bgfx.getRendererType();
        const vs_post = @import("shader_module").vs_post.getShaderForRenderer(backend);
        const fs_post = @import("shader_module").fs_post.getShaderForRenderer(backend);
        const post_prog = try renderer.createProgramFromMemory(vs_post, fs_post);

        const scene_fb = try renderer.createFramebufferSimple(width, height, false);
        const scene_tex = renderer.getFramebufferTexture(scene_fb, 0);
        const post_mesh = try renderer.createPostQuad();

        var post_mat = material.Material.init(post_prog, allocator);
        try post_mat.setTexture(0, scene_tex, "s_sceneColor");
        try post_mat.setVec4("u_exposure", .{ 1.0, 0.0, 0.0, 0.0 });

        return .{
            .allocator = allocator,
            .res = renderer,
            .scene_fb = scene_fb,
            .scene_tex = scene_tex,
            .post_mesh = post_mesh,
            .post_mat = post_mat,
            .screen_view_id = screen_view_id,
            .width = width,
            .height = height,
            .exposure = 1.0,
            .vignette_strength = 0.0,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.post_mat.deinit(self.res);
    }

    /// Set exposure (brightness multiplier)
    pub fn setExposure(self: *Self, value: f32) !void {
        self.exposure = value;
        try self.post_mat.setVec4("u_exposure", .{ self.exposure, self.vignette_strength, 0.0, 0.0 });
    }

    /// Set vignette effect
    /// strength: 0.0 = off, 1.0 = strong darkening at edges
    pub fn setVignette(self: *Self, strength: f32) !void {
        self.vignette_strength = strength;
        try self.post_mat.setVec4("u_exposure", .{ self.exposure, self.vignette_strength, 0.0, 0.0 });
    }

    /// Begin rendering the scene - call this before rendering geometry
    /// The scene will render to the internal framebuffer
    pub fn beginScenePass(self: *const Self, view_id: u8) void {
        const fb = self.res.getFramebuffer(self.scene_fb);
        if (fb) |f| {
            bgfx.setViewFrameBuffer(view_id, f.handle);
            bgfx.setViewRect(view_id, 0, 0, f.width, f.height);
            bgfx.setViewClear(view_id, bgfx.ClearFlags_Color, 0x000000FF, 1.0, 0);
        }
    }

    /// End scene rendering and render post-processed result to screen
    /// Call this after rendering all geometry
    pub fn endScenePass(self: *const Self) void {
        self.beginScreenPass();
        self.renderPostQuad();
    }

    /// Set up the screen view for post-processing
    pub fn beginScreenPass(self: *const Self) void {
        bgfx.setViewFrameBuffer(self.screen_view_id, .{ .idx = 0xFFFF });
        bgfx.setViewRect(self.screen_view_id, 0, 0, self.width, self.height);
        bgfx.setViewClear(self.screen_view_id, bgfx.ClearFlags_Color, 0x303030FF, 1.0, 0);

        var ident: [16]f32 = undefined;
        for (0..16) |i| ident[i] = if (i % 5 == 0) 1.0 else 0.0;
        bgfx.setViewTransform(self.screen_view_id, &ident, null);
    }

    /// Render the post-processing quad to the screen
    pub fn renderPostQuad(self: *const Self) void {
        var ident: [16]f32 = undefined;
        for (0..16) |i| ident[i] = if (i % 5 == 0) 1.0 else 0.0;
        _ = bgfx.setTransform(&ident, 1);

        const m = self.res.getMesh(self.post_mesh) orelse return;
        const p = self.res.getProgram(self.post_mat.program) orelse return;

        bgfx.setVertexBuffer(0, m.vbh, 0, m.vertex_count);
        bgfx.setIndexBuffer(m.ibh, 0, m.index_count);
        self.post_mat.bind(self.res);
        bgfx.setState(bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_WriteZ, 0);
        _ = bgfx.submit(self.screen_view_id, p.handle, 0, bgfx.DiscardFlags_All);
    }

    /// Get the internal framebuffer handle
    pub fn getFramebufferHandle(self: *const Self) resources.FramebufferHandle {
        return self.scene_fb;
    }
};
