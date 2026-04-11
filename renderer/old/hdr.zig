/// hdr.zig
/// HDR render target + tonemapping post-process pass.
///
/// Usage:
///   1. Call hdr.init() once after bgfx init
///   2. In setupDefaultPasses, geometry renders to view 1 (hdr.geometry_view)
///      with hdr.framebuffer as the render target
///   3. After geometry pass, call hdr.submitTonemapPass() to blit to backbuffer
///   4. Call hdr.deinit() on shutdown
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const isValid = @import("bgfx_util.zig").isValid;
const resources = @import("resources.zig");

pub const HDR_VIEW: u8 = 1; // geometry renders here → HDR framebuffer
pub const TONEMAP_VIEW: u8 = 10; // fullscreen quad → backbuffer

// ─────────────────────────────────────────────────────────────
// Fullscreen triangle (NDC, no index buffer needed)
// One triangle that covers the entire screen.
// ─────────────────────────────────────────────────────────────

const FSVertex = struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
};

const fs_verts = [3]FSVertex{
    .{ .x = -1.0, .y = -1.0, .u = 0.0, .v = 1.0 },
    .{ .x = 3.0, .y = -1.0, .u = 2.0, .v = 1.0 },
    .{ .x = -1.0, .y = 3.0, .u = 0.0, .v = -1.0 },
};

pub const TonemapParams = struct {
    exposure: f32 = 1.0,
    bloom_strength: f32 = 0.0,
    /// 0 = ACES (default), 1 = Reinhard, 2 = Uncharted2
    tonemapper: f32 = 0.0,
};

pub const HdrPipeline = struct {
    width: u16,
    height: u16,

    // HDR framebuffer (RGBA16F color + D24 depth)
    framebuffer: bgfx.FrameBufferHandle,
    hdr_texture: bgfx.TextureHandle, // color attachment (sampled in tonemap pass)

    // Fullscreen triangle GPU buffers
    fs_vbh: bgfx.VertexBufferHandle,
    fs_layout: bgfx.VertexLayout,

    // Tonemap shader program
    tonemap_program: bgfx.ProgramHandle,
    tonemap_vert: bgfx.ShaderHandle,
    tonemap_frag: bgfx.ShaderHandle,

    // Uniforms
    u_hdrBuffer: bgfx.UniformHandle,
    u_bloom: bgfx.UniformHandle,
    u_tonemapParams: bgfx.UniformHandle,

    // White 1x1 fallback for bloom when not enabled
    white_tex: bgfx.TextureHandle,

    params: TonemapParams = .{},

    pub fn init(
        self: *HdrPipeline,
        width: u16,
        height: u16,
        vs_tonemap_mem: [*c]const bgfx.Memory,
        fs_tonemap_mem: [*c]const bgfx.Memory,
    ) !void {
        self.width = width;
        self.height = height;

        // ── HDR framebuffer ───────────────────────────────────
        // Color: RGBA16F (HDR)
        // Depth: D24S8
        // const color_flags: u64 =
        //     bgfx.TextureFlags_Rt |
        //     @as(u64, @intFromEnum(bgfx.TextureFormat.RGBA16F)) << 32;
        // const depth_flags: u64 =
        //     bgfx.TextureFlags_RtWriteOnly |
        //     @as(u64, @intFromEnum(bgfx.TextureFormat.D24S8)) << 32;

        var attachments = [2]bgfx.Attachment{
            std.mem.zeroes(bgfx.Attachment),
            std.mem.zeroes(bgfx.Attachment),
        };
        attachments[0].init(
            bgfx.createTexture2D(width, height, false, 1, .RGBA16F, bgfx.TextureFlags_Rt, null, 0),
            .Write,
            0,
            1,
            0,
            bgfx.ResolveFlags_None,
        );
        attachments[1].init(
            bgfx.createTexture2D(width, height, false, 1, .D24S8, bgfx.TextureFlags_RtWriteOnly, null, 0),
            .Write,
            0,
            1,
            0,
            bgfx.ResolveFlags_None,
        );

        self.hdr_texture = attachments[0].handle;
        self.framebuffer = bgfx.createFrameBufferFromAttachment(2, &attachments, false);
        if (!isValid(self.framebuffer)) return error.FramebufferCreationFailed;

        // ── Fullscreen triangle layout ────────────────────────
        const backend = bgfx.getRendererType();
        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(backend);
        _ = layout.add(.Position, 2, .Float, false, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        layout.end();
        self.fs_layout = layout;

        const vb_mem = bgfx.copy(&fs_verts, @sizeOf(@TypeOf(fs_verts)));
        self.fs_vbh = bgfx.createVertexBuffer(vb_mem, &self.fs_layout, bgfx.BufferFlags_None);

        // ── Tonemap shader ────────────────────────────────────
        self.tonemap_vert = bgfx.createShader(vs_tonemap_mem);
        self.tonemap_frag = bgfx.createShader(fs_tonemap_mem);
        if (!isValid(self.tonemap_vert)) return error.InvalidTonemapVert;
        if (!isValid(self.tonemap_frag)) return error.InvalidTonemapFrag;
        self.tonemap_program = bgfx.createProgram(self.tonemap_vert, self.tonemap_frag, false);
        if (!isValid(self.tonemap_program)) return error.InvalidTonemapProgram;

        // ── Uniforms ──────────────────────────────────────────
        self.u_hdrBuffer = bgfx.createUniform("s_hdrBuffer", .Sampler, 1);
        self.u_bloom = bgfx.createUniform("s_bloom", .Sampler, 1);
        self.u_tonemapParams = bgfx.createUniform("u_tonemapParams", .Vec4, 1);

        // ── White fallback for bloom ──────────────────────────
        const white: [4]u8 = .{ 0xFF, 0xFF, 0xFF, 0xFF };
        const white_mem = bgfx.copy(&white, 4);
        self.white_tex = bgfx.createTexture2D(1, 1, false, 1, .RGBA8, bgfx.TextureFlags_None, white_mem, 0);
    }

    pub fn deinit(self: *HdrPipeline) void {
        bgfx.destroyUniform(self.u_hdrBuffer);
        bgfx.destroyUniform(self.u_bloom);
        bgfx.destroyUniform(self.u_tonemapParams);
        bgfx.destroyVertexBuffer(self.fs_vbh);
        bgfx.destroyShader(self.tonemap_vert);
        bgfx.destroyShader(self.tonemap_frag);
        bgfx.destroyProgram(self.tonemap_program);
        bgfx.destroyTexture(self.white_tex);
        bgfx.destroyFrameBuffer(self.framebuffer);
    }

    /// Call once per frame AFTER the geometry pass has been submitted.
    /// Renders a fullscreen triangle that tonemaps the HDR buffer to the backbuffer.
    /// bloom_tex: pass a valid texture handle for bloom, or .invalid to skip.
    pub fn submitTonemapPass(
        self: *HdrPipeline,
        bloom_tex: bgfx.TextureHandle,
    ) void {
        const vid = TONEMAP_VIEW;

        // Render to backbuffer (no framebuffer set = default backbuffer)
        bgfx.setViewFrameBuffer(vid, .{ .idx = std.math.maxInt(u16) });
        bgfx.setViewRect(vid, 0, 0, self.width, self.height);
        bgfx.setViewClear(vid, 0, 0, 1.0, 0); // no clear needed

        // Bind HDR texture
        bgfx.setTexture(0, self.u_hdrBuffer, self.hdr_texture, std.math.maxInt(u32));

        // Bind bloom (or white fallback)
        const bloom = if (isValid(bloom_tex)) bloom_tex else self.white_tex;
        bgfx.setTexture(1, self.u_bloom, bloom, std.math.maxInt(u32));

        // Tonemap params
        const p = [4]f32{
            self.params.exposure,
            self.params.bloom_strength,
            self.params.tonemapper,
            0.0,
        };
        bgfx.setUniform(self.u_tonemapParams, &p, 1);

        // Fullscreen triangle — no depth test, no culling
        const state =
            bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA;

        bgfx.setVertexBuffer(0, self.fs_vbh, 0, 3);
        bgfx.setState(state, 0);
        _ = bgfx.submit(vid, self.tonemap_program, 0, bgfx.DiscardFlags_All);
    }

    /// Attach the HDR framebuffer to a bgfx view so geometry renders into it.
    pub fn attachToView(self: *HdrPipeline, view_id: u8) void {
        bgfx.setViewFrameBuffer(view_id, self.framebuffer);
    }

    /// Call when window is resized.
    pub fn resize(self: *HdrPipeline, width: u16, height: u16) !void {
        self.deinit();
        // Re-init preserves program/uniforms recreation — simplest approach.
        // In production you'd recreate only the textures.
        self.width = width;
        self.height = height;
        // Caller must re-call init with the shader mems again,
        // or cache them. For now signal that resize needs re-init.
        return error.ResizeRequiresReinit;
    }
};
