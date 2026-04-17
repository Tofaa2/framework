/// Declarative post-processing pipeline.
/// Allows chained passes with automatic resource management and dependency tracking.
///
/// Usage:
/// ```zig
/// var graph = try RenderGraph.init(allocator, rw.width, rw.height);
/// defer graph.deinit();
///
/// // Declare resources
/// graph.addExternal("scene", rw.getSceneTexture().?);
/// graph.addExternal("depth", rw.getDepthTexture().?);
/// graph.addInternal("bloom_h", .half);
/// graph.addInternal("bloom_v", .half);
///
/// // Add passes
/// try graph.addPass(.{
///     .name = "threshold",
///     .program = threshold_prog,
///     .input = "scene",
///     .output = "bright",
/// });
///
/// try graph.addPass(.{
///     .name = "blur_h",
///     .program = blur_prog,
///     .input = "bright",
///     .output = "bloom_h",
/// });
///
/// graph.compile();
/// // Then in render loop:
/// graph.run(&uniforms, &post_process_state);
/// ```
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");
const ShaderProgram = @import("ShaderProgram.zig");
const DrawEncoder = @import("DrawEncoder.zig");
const UniformStore = @import("UniformStore.zig");
const Texture = @import("Texture.zig");
const Framebuffer = @import("Framebuffer.zig");
const RenderGraph = @This();

/// Full-screen quad vertices (big triangle technique)
const FsVertex = struct { x: f32, y: f32, u: f32, v: f32 };
const FS_VERTS = [_]FsVertex{
    .{ .x = -1, .y = -1, .u = 0, .v = 1 },
    .{ .x = 3, .y = -1, .u = 2, .v = 1 },
    .{ .x = -1, .y = 3, .u = 0, .v = -1 },
};
const FS_INDICES = [_]u16{ 0, 2, 1 };

const PASS_STATE_DEFAULT: u64 =
    bgfx.StateFlags_WriteRgb |
    bgfx.StateFlags_WriteA;

pub const BindFn = *const fn (enc: DrawEncoder, uniforms: *UniformStore, pass_index: u32) void;

pub const ResolutionScale = enum {
    full,
    half,
    quarter,
};

pub const Resource = struct {
    name: []const u8,
    kind: Kind,

    pub const Kind = union(enum) {
        external: bgfx.TextureHandle,
        internal: Internal,
    };

    pub const Internal = struct {
        scale: ResolutionScale,
        format: bgfx.TextureFormat,
    };
};

pub const Pass = struct {
    name: []const u8,
    program: ShaderProgram,
    inputs: []const []const u8,
    output: ?[]const u8 = null,
    bind_fn: ?BindFn = null,
    input_samplers: ?[]const []const u8 = null,
};

const CompiledPass = struct {
    name: []const u8,
    program: ShaderProgram,
    input_refs: []const *CompiledResource,
    output_ref: ?*CompiledResource,
    bind_fn: ?BindFn,
    input_samplers: []const []const u8,
    fb: ?Framebuffer,
    view: u16,
    scale: ResolutionScale,
};

const CompiledResource = struct {
    name: []const u8,
    kind: Resource.Kind,
    texture: ?Texture,
    fb: ?Framebuffer,
};

allocator: std.mem.Allocator,
base_width: u32,
base_height: u32,
resources: std.ArrayListUnmanaged(Resource),
passes: std.ArrayListUnmanaged(Pass),
compiled_resources: std.ArrayListUnmanaged(CompiledResource),
compiled_passes: std.ArrayListUnmanaged(CompiledPass),
fs_vb: bgfx.VertexBufferHandle,
fs_ib: bgfx.IndexBufferHandle,
next_view: u16,
compiled: bool,

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !RenderGraph {
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
        .allocator = allocator,
        .base_width = width,
        .base_height = height,
        .resources = .{},
        .passes = .{},
        .compiled_resources = .{},
        .compiled_passes = .{},
        .fs_vb = vb,
        .fs_ib = ib,
        .next_view = 2,
        .compiled = false,
    };
}

pub fn deinit(self: *RenderGraph) void {
    for (self.compiled_passes.items) |*cp| {
        cp.program.deinit();
        if (cp.fb) |*fb| fb.deinit();
        self.allocator.free(cp.input_samplers);
    }
    self.compiled_passes.deinit(self.allocator);

    for (self.compiled_resources.items) |*cr| {
        if (cr.fb) |*fb| fb.deinit();
        if (cr.texture) |*tex| tex.deinit();
    }
    self.compiled_resources.deinit(self.allocator);

    self.passes.deinit(self.allocator);
    self.resources.deinit(self.allocator);

    bgfx.destroyVertexBuffer(self.fs_vb);
    bgfx.destroyIndexBuffer(self.fs_ib);
}

pub fn addExternal(self: *RenderGraph, name: []const u8, texture: bgfx.TextureHandle) !void {
    try self.resources.append(self.allocator, .{
        .name = name,
        .kind = .{ .external = texture },
    });
}

pub fn addInternal(self: *RenderGraph, name: []const u8, scale: ResolutionScale) !void {
    try self.resources.append(self.allocator, .{
        .name = name,
        .kind = .{ .internal = .{
            .scale = scale,
            .format = .RGBA16F,
        } },
    });
}

pub fn addPass(self: *RenderGraph, pass: Pass) !void {
    try self.passes.append(self.allocator, pass);
}

pub fn compile(self: *RenderGraph) !void {
    std.debug.assert(!self.compiled);
    self.compiled = true;

    for (self.resources.items) |res| {
        var cr = CompiledResource{
            .name = res.name,
            .kind = res.kind,
            .texture = null,
            .fb = null,
        };
        if (res.kind == .internal) {
            const w = switch (res.kind.internal.scale) {
                .full => self.base_width,
                .half => self.base_width / 2,
                .quarter => self.base_width / 4,
            };
            const h = switch (res.kind.internal.scale) {
                .full => self.base_height,
                .half => self.base_height / 2,
                .quarter => self.base_height / 4,
            };
            cr.fb = try Framebuffer.init(self.allocator, .{
                .attachments = &.{.{ .color = .{ .format = res.kind.internal.format } }},
                .width = w,
                .height = h,
            });
        }
        try self.compiled_resources.append(self.allocator, cr);
    }

    var cr_map: std.StringHashMap(*CompiledResource) = .init(self.allocator);
    defer cr_map.deinit();

    for (self.compiled_resources.items) |*cr| {
        try cr_map.put(cr.name, cr);
    }

    for (self.passes.items) |pass| {
        const scale = blk: {
            if (pass.output) |out_name| {
                if (cr_map.get(out_name)) |cr| {
                    if (cr.kind == .internal) break :blk cr.kind.internal.scale;
                }
            }
            break :blk .full;
        };

        var input_refs: std.ArrayListUnmanaged(*CompiledResource) = .{};
        for (pass.inputs) |input_name| {
            if (cr_map.get(input_name)) |cr| {
                try input_refs.append(self.allocator, cr);
            }
        }

        var output_ref: ?*CompiledResource = null;
        if (pass.output) |out_name| {
            if (cr_map.get(out_name)) |cr| {
                output_ref = cr;
            }
        }

        const view = self.next_view;
        self.next_view += 1;

        var fb: ?Framebuffer = null;
        if (output_ref) |cr| {
            if (cr.kind == .internal) {
                fb = cr.fb;
            }
        }

        const input_refs_slice = try input_refs.toOwnedSlice(self.allocator);

        const samplers = pass.input_samplers orelse &.{};
        const samplers_slice = try self.allocator.dupe([]const u8, samplers);

        try self.compiled_passes.append(self.allocator, .{
            .name = pass.name,
            .program = pass.program,
            .input_refs = input_refs_slice,
            .output_ref = output_ref,
            .bind_fn = pass.bind_fn,
            .input_samplers = samplers_slice,
            .fb = fb,
            .view = view,
            .scale = scale,
        });
    }
}

pub fn getOutput(self: *RenderGraph, name: []const u8) ?bgfx.TextureHandle {
    for (self.compiled_resources.items) |res| {
        if (std.mem.eql(u8, res.name, name)) {
            if (res.kind == .external) {
                return res.kind.external;
            } else if (res.fb) |fb| {
                return fb.colorTexture();
            }
        }
    }
    return null;
}

pub fn run(self: *RenderGraph, uniforms: *UniformStore, user_data: ?*anyopaque) void {
    _ = user_data;
    bgfx.discard(bgfx.DiscardFlags_All);
    for (self.compiled_passes.items, 0..) |*pass, i| {
        const w = switch (pass.scale) {
            .full => self.base_width,
            .half => self.base_width / 2,
            .quarter => self.base_width / 4,
        };
        const h = switch (pass.scale) {
            .full => self.base_height,
            .half => self.base_height / 2,
            .quarter => self.base_height / 4,
        };

        bgfx.setViewTransform(pass.view, null, null);
        bgfx.setViewRect(pass.view, 0, 0, @intCast(w), @intCast(h));
        bgfx.setViewClear(pass.view, bgfx.ClearFlags_None, 0, 1.0, 0);

        if (pass.fb) |fb| {
            bgfx.setViewFrameBuffer(pass.view, fb.handle);
        }

        const enc = DrawEncoder.init(pass.view);

        for (pass.input_refs, 0..) |res, stage| {
            const tex = getResourceTexture(res);
            const sampler_name = if (stage < pass.input_samplers.len)
                pass.input_samplers[stage]
            else
                "s_graphInput0";
            const sampler = uniforms.getOrCreate(sampler_name, bgfx.UniformType.Sampler, 1);
            enc.setTexture(@intCast(stage), sampler, tex, 0);
        }

        if (pass.bind_fn) |bind| {
            bind(enc, uniforms, @intCast(i));
        }

        enc.setVertexBuffer(self.fs_vb, 0, FS_VERTS.len);
        enc.setIndexBuffer(self.fs_ib, 0, FS_INDICES.len);
        enc.setStateFlags(PASS_STATE_DEFAULT);
        enc.submit(pass.program, 0);
        bgfx.discard(bgfx.DiscardFlags_All);
    }
}

fn getResourceTexture(res: *CompiledResource) bgfx.TextureHandle {
    switch (res.kind) {
        .external => |h| return h,
        .internal => {
            if (res.fb) |fb| return fb.colorTexture();
            return bgfx.TextureHandle{ .idx = 0 };
        },
    }
}
