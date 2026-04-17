/// Post-processing pass chain.
/// Manages a sequence of full-screen passes that transform the rendered scene.
///
/// Usage:
/// ```zig
/// var post = try PostProcess.init(allocator);
/// try post.addPass(.{
///     .program = my_shader_program,
///     .input = scene_tex,
///     .bind_fn = myBindCallback,  // Set uniforms for this pass
/// });
/// rw.setPostProcess(&post);
/// ```
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const ShaderProgram = @import("ShaderProgram.zig");
const DrawEncoder = @import("DrawEncoder.zig");
const UniformStore = @import("UniformStore.zig");
const PostProcess = @This();

/// Full-screen quad vertices (big triangle technique)
const FsVertex = struct { x: f32, y: f32, u: f32, v: f32 };
const FS_VERTS = [_]FsVertex{
    .{ .x = -1, .y = -1, .u = 0, .v = 1 },
    .{ .x = 3, .y = -1, .u = 2, .v = 1 },
    .{ .x = -1, .y = 3, .u = 0, .v = -1 },
};
const FS_INDICES = [_]u16{ 0, 2, 1 };

/// Callback type for binding pass-specific uniforms.
/// Called before each pass is submitted.
pub const BindFn = *const fn (enc: DrawEncoder, uniforms: *UniformStore, pass_index: u32) void;

/// A single post-processing pass.
pub const Pass = struct {
    /// The shader program for this pass.
    program: ShaderProgram,
    /// Texture to sample for input (e.g. scene color buffer).
    input: bgfx.TextureHandle,
    /// Sampler uniform name to bind input texture (default: "s_texColor").
    input_uniform: []const u8 = "s_texColor",
    /// bgfx view to render into. Default (2) outputs to screen/backbuffer.
    output: u16 = 2,
    /// Optional depth texture.
    depth: ?bgfx.TextureHandle = null,
    /// Sampler uniform name for depth texture (default: "s_depth").
    depth_uniform: []const u8 = "s_depth",
    /// Callback to bind uniforms for this pass. Called after textures are bound.
    bind_fn: ?BindFn = null,
};

/// State
passes: std.ArrayListUnmanaged(Pass),
allocator: std.mem.Allocator,
fs_vb: bgfx.VertexBufferHandle,
fs_ib: bgfx.IndexBufferHandle,

pub fn init(allocator: std.mem.Allocator) !PostProcess {
    var layout: bgfx.VertexLayout = undefined;
    _ = layout.begin(bgfx.getRendererType());
    _ = layout.add(.Position, 2, .Float, false, false);
    _ = layout.add(.TexCoord0, 2, .Float, false, false);
    layout.end();

    const vm = bgfx.copy(@ptrCast(&FS_VERTS), @sizeOf(@TypeOf(FS_VERTS)));
    const im = bgfx.copy(@ptrCast(&FS_INDICES), @sizeOf(@TypeOf(FS_INDICES)));
    const vb = bgfx.createVertexBuffer(vm, &layout, bgfx.BufferFlags_None);
    const ib = bgfx.createIndexBuffer(im, bgfx.BufferFlags_None);

    return .{
        .passes = .{},
        .allocator = allocator,
        .fs_vb = vb,
        .fs_ib = ib,
    };
}

pub fn deinit(self: *PostProcess) void {
    for (self.passes.items) |*p| p.program.deinit();
    self.passes.deinit(self.allocator);
    bgfx.destroyVertexBuffer(self.fs_vb);
    bgfx.destroyIndexBuffer(self.fs_ib);
}

pub fn addPass(self: *PostProcess, pass: Pass) !void {
    try self.passes.append(self.allocator, pass);
}

pub fn clearPasses(self: *PostProcess) void {
    for (self.passes.items) |*p| p.program.deinit();
    self.passes.clearRetainingCapacity();
}

pub fn run(self: *PostProcess, uniforms: *UniformStore, width: u32, height: u32) void {
    for (self.passes.items, 0..) |*pass, i| {
        bgfx.setViewTransform(pass.output, null, null);
        bgfx.setViewRect(pass.output, 0, 0, @intCast(width), @intCast(height));
        bgfx.setViewClear(pass.output, bgfx.ClearFlags_None, 0, 1.0, 0);

        const enc = DrawEncoder.init(pass.output);

        const h_input = uniforms.sampler(pass.input_uniform);
        enc.setTexture(0, h_input, pass.input, 0);

        if (pass.depth) |depth| {
            const h_depth = uniforms.sampler(pass.depth_uniform);
            enc.setTexture(1, h_depth, depth, 0);
        }

        if (pass.bind_fn) |bind| {
            bind(enc, uniforms, @intCast(i));
        }

        enc.setVertexBuffer(self.fs_vb, 0, FS_VERTS.len);
        enc.setIndexBuffer(self.fs_ib, 0, FS_INDICES.len);
        enc.setStateFlags(
            bgfx.StateFlags_WriteRgb |
                bgfx.StateFlags_WriteA,
        );
        enc.submitPreserveState(pass.program);
    }
}
