const std = @import("std");
pub const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;
const shaders = @import("shader_module");
pub const math = @import("math.zig");
const zm = math;
var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};

pub const Viewport = @import("Viewport.zig");
pub const Image = @import("Image.zig");
pub const ShaderProgram = @import("ShaderProgram.zig");
pub const log = std.log.scoped(.renderer);
const isValid = @import("bgfx_util.zig").isValid;
pub const Color = @import("Color.zig");
pub const RenderBatch = @import("RenderBatch.zig");
pub const View = @import("View.zig");
pub const Vertex = @import("Vertex.zig");

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    viewport: Viewport,
    program: ShaderProgram,
    tex_uniform: bgfx.UniformHandle,

    white_texture: Image,
    vertex_layout: bgfx.VertexLayout,

    views: View.Map,

    pub fn getView(self: *Renderer, id: View.Id) ?*View {
        return self.views.getPtr(id);
    }

    pub fn init(
        allocator: std.mem.Allocator,
        viewport: Viewport,
        window_ptr: ?*anyopaque,
        debug: bool,
    ) !Renderer {
        var bgfx_init = std.mem.zeroes(bgfx.Init);
        bgfx.initCtor(&bgfx_init);

        bgfx_init.platformData.nwh = window_ptr;
        bgfx_init.type = .Count;
        bgfx_init.resolution.width = viewport.width;
        bgfx_init.resolution.height = viewport.height;
        bgfx_init.debug = debug;
        bgfx_init.callback = &bgfx_clbs;

        if (!bgfx.init(&bgfx_init)) {
            return error.InitFailed;
        }

        bgfx.setDebug(bgfx.DebugFlags_Stats);
        const tex_uniform = bgfx.createUniform("s_texColor", .Sampler, 1);
        const backend = bgfx.getRendererType();
        const program = try ShaderProgram.initFromMem(shaders.vs_basic.getShaderForRenderer(backend), shaders.fs_basic.getShaderForRenderer(backend));

        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(backend);
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.Color0, 4, .Uint8, true, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        layout.end();

        var views = View.Map.init(allocator);
        views.put(.@"2d", .{
            .proj_mtx = math.orthographicOffCenterRhGl(0.0, @floatFromInt(viewport.width), @floatFromInt(viewport.height), 0.0, -1.0, 1.0),
            .id = .@"2d",
            .allocator = allocator,
        }) catch unreachable;

        views.put(.@"3d", .{
            .proj_mtx = zm.perspectiveFovRhGl(
                0.25 * std.math.pi, // 45 degree fov
                @as(f32, @floatFromInt(viewport.width)) / @as(f32, @floatFromInt(viewport.height)),
                0.1, // near plane
                100.0, // far plane
            ),
            .view_mtx = zm.lookAtRh(
                zm.f32x4(0.0, 0.0, -10.0, 1.0), // camera position
                zm.f32x4(0.0, 0.0, 0.0, 1.0), // looking at origin
                zm.f32x4(0.0, 1.0, 0.0, 0.0), // up vector
            ),
            .id = .@"3d",
            .allocator = allocator,
        }) catch unreachable;

        return Renderer{
            .allocator = allocator,
            .viewport = viewport,
            .program = program,
            .white_texture = Image.initSingleColor(.white),
            .vertex_layout = layout,
            .views = views,
            .tex_uniform = tex_uniform,
        };
    }

    pub fn resize(self: *Renderer, width: u32, height: u32) void {
        self.viewport.width = width;
        self.viewport.height = height;

        bgfx.reset(width, height, bgfx.ResetFlags_None, bgfx.TextureFormat.Count);

        if (self.views.getPtr(.@"2d")) |v| {
            v.proj_mtx = math.orthographicOffCenterRhGl(
                0.0,
                @floatFromInt(width),
                @floatFromInt(height),
                0.0,
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
    }

    pub fn draw(self: *Renderer) void {
        var iter = self.views.iterator();
        while (iter.next()) |entry| {
            const view = entry.value_ptr;
            const view_id: u8 = @intFromEnum(view.id);

            bgfx.setViewClear(view_id, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, view.clear_color.toABGR(), 1.0, 0.0);
            bgfx.setViewRect(view_id, 0, 0, @intCast(self.viewport.width), @intCast(self.viewport.height));
            bgfx.setViewTransform(view_id, &math.matToArr(view.view_mtx), &math.matToArr(view.proj_mtx));

            for (view.batches.items) |batch| {
                if (batch.transform) |transform| {
                    _ = bgfx.setTransform(&math.matToArr(zm.transpose(transform)), 1);
                }

                const state = bgfx.StateFlags_WriteRgb |
                    bgfx.StateFlags_WriteA |
                    bgfx.StateFlags_WriteZ |
                    bgfx.StateFlags_DepthTestLess;
                bgfx.setState(state, 0);

                if (batch.texture) |tex| {
                    bgfx.setTexture(0, self.tex_uniform, tex.handle, std.math.maxInt(u32));
                } else {
                    bgfx.setTexture(0, self.tex_uniform, self.white_texture.handle, std.math.maxInt(u32));
                }

                var tvb: bgfx.TransientVertexBuffer = undefined;
                var tib: bgfx.TransientIndexBuffer = undefined;
                if (!bgfx.allocTransientBuffers(&tvb, &self.vertex_layout, @intCast(batch.vertices.items.len), &tib, @intCast(batch.indices.items.len), false)) {
                    log.err("Failed to allocate transient buffers for batch", .{});
                    return;
                }
                @memcpy(tvb.data[0..(@sizeOf(Vertex) * batch.vertices.items.len)], std.mem.sliceAsBytes(batch.vertices.items));
                @memcpy(tib.data[0..(batch.indices.items.len * 2)], std.mem.sliceAsBytes(batch.indices.items));

                bgfx.setTransientVertexBuffer(0, &tvb, 0, @intCast(batch.vertices.items.len));
                bgfx.setTransientIndexBuffer(&tib, 0, @intCast(batch.indices.items.len));

                const program_handle = if (batch.shader) |shader| shader.program_handle else self.program.program_handle;

                _ = bgfx.submit(view_id, program_handle, 0, bgfx.DiscardFlags_All);
            }
            for (view.batches.items) |*batch| {
                batch.vertices.clearRetainingCapacity();
                batch.indices.clearRetainingCapacity();
            }
            view.batches.clearRetainingCapacity();
        }
        _ = bgfx.frame(bgfx.FrameFlags_None);
    }

    pub fn deinit(self: *Renderer) void {
        self.program.deinit();
        self.white_texture.deinit();
        bgfx.shutdown();
        self.views.deinit();
    }
};
