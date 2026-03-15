const std = @import("std");
pub const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;
const shaders = @import("shader_module");
pub const math = @import("math.zig");
const zm = math;
var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};

pub const geometry = @import("geometry_builder.zig");
pub const Viewport = @import("Viewport.zig");
pub const Image = @import("Image.zig");
pub const ShaderProgram = @import("ShaderProgram.zig");
pub const log = std.log.scoped(.renderer);
const isValid = @import("bgfx_util.zig").isValid;
pub const Color = @import("Color.zig");

const runtime = @import("runtime");
const window = @import("window");

pub const Plugin = struct {
    pub const dependencies = .{@import("window").Plugin};

    pub fn init(_: *Plugin, context: *runtime.App) void {
        var w = context.resources.getMut(window.api.Window).?;
        const framebuffer = w.getFrameBufferSize();
        const width = framebuffer[0];
        const height = framebuffer[1];
        const renderer = Renderer.init(context.allocators.generic, .{
            .height = @intCast(height),
            .width = @intCast(width),
        }, w.getNativePtr(), false) catch unreachable;
        context.resources.add(renderer) catch unreachable;
        context.scheduler.addStage(.{ .name = "renderer", .phase = .update, .run = runUpdate }) catch unreachable;
        log.info("Renderer Plugin Initialized, NATIVE PTR: {any}", .{renderer});
    }

    pub fn deinit(_: *Plugin, context: *runtime.App) void {
        const r = context.resources.getMut(Renderer) orelse return;
        r.deinit();
    }
};

fn runUpdate(context: *runtime.App) void {
    const r = context.resources.getMut(Renderer) orelse return;

    r.draw();
}

pub const Views = enum(u8) {
    @"3d" = 0,
    @"2d" = 1,
};

pub const Vertex = @import("Vertex.zig");

pub const triangle_vertices = [_]Vertex{
    .init(.{ 0.0, 0.5, 0.0 }, .red, null),
    .init(.{ -0.5, -0.5, 0.0 }, .green, null),
    .init(.{ 0.5, -0.5, 0.0 }, .blue, null),
};

pub const triangle_indices = [_]u16{ 0, 1, 2 };

const cube_vertices = [_]Vertex{
    .init(.{ -1.0, 1.0, 1.0 }, .black, null),
    .init(.{ 1.0, 1.0, 1.0 }, .blue, null),
    .init(.{ -1.0, -1.0, 1.0 }, .green, null),
    .init(.{ 1.0, -1.0, 1.0 }, .cyan, null),
    .init(.{ -1.0, 1.0, -1.0 }, .red, null),
    .init(.{ 1.0, 1.0, -1.0 }, .magenta, null),
    .init(.{ -1.0, -1.0, -1.0 }, .yellow, null),
    .init(.{ 1.0, -1.0, -1.0 }, .white, null),
};

const cube_indices = [_]u16{
    0, 1, 2, // 0
    1, 3, 2,
    4, 6, 5, // 2
    5, 6, 7,
    0, 2, 4, // 4
    4, 2, 6,
    1, 5, 3, // 6
    5, 7, 3,
    0, 4, 1, // 8
    4, 5, 1,
    2, 3, 6, // 10
    6, 3, 7,
};
pub const Batcher = struct {
    vertices: std.ArrayListUnmanaged(Vertex) = .empty,
    indices: std.ArrayListUnmanaged(u16) = .empty,

    pub fn pushQuad(self: *Batcher, allocator: std.mem.Allocator, pos: [3]f32, size: [2]f32, color: Color) !void {
        const offset = @as(u16, @intCast(self.vertices.items.len));
        // const c = color.toABGR();

        try self.vertices.appendSlice(allocator, &[_]Vertex{
            .init(.{ pos[0], pos[1], pos[2] }, color, .{ 0, 0 }),
            .init(.{ pos[0] + size[0], pos[1], pos[2] }, color, .{ 1, 0 }),
            .init(.{ pos[0], pos[1] + size[1], pos[2] }, color, .{ 0, 1 }),
            .init(.{ pos[0] + size[0], pos[1] + size[1], pos[2] }, color, .{ 1, 1 }),
        });

        try self.indices.appendSlice(allocator, &[_]u16{
            offset + 0, offset + 1, offset + 2,
            offset + 1, offset + 3, offset + 2,
        });
    }
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    viewport: Viewport,
    program: ShaderProgram,
    vbh: bgfx.VertexBufferHandle,
    ibh: bgfx.IndexBufferHandle,
    white_texture: Image,
    vertex_layout: bgfx.VertexLayout,
    view_mtx: zm.Mat,
    proj_mtx: zm.Mat,
    accum_time: f32,
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

        // bgfx.setDebug(bgfx.DebugFlags_Stats);

        const backend = bgfx.getRendererType();
        const program = try ShaderProgram.initFromMem(shaders.vs_basic.getShaderForRenderer(backend), shaders.fs_basic.getShaderForRenderer(backend));

        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(backend);
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.Color0, 4, .Uint8, true, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        layout.end();

        const trig_mem = bgfx.makeRef(&cube_vertices, @intCast(@sizeOf(Vertex) * cube_vertices.len));
        const vbh = bgfx.createVertexBuffer(trig_mem, &layout, bgfx.BufferFlags_None);
        if (!isValid(vbh)) {
            log.err("Invalid Vertex Buffer\n", .{});
            return error.InvalidVertexBuffer;
        }

        const trig_indices_mem = bgfx.makeRef(&cube_indices, @intCast(@sizeOf(u16) * cube_indices.len));
        const ibh = bgfx.createIndexBuffer(trig_indices_mem, bgfx.BufferFlags_None);
        if (!isValid(ibh)) {
            log.err("Invalid Index Buffer\n", .{});
            return error.InvalidIndexBuffer;
        }

        const viewMtx = zm.lookAtRh(zm.f32x4(0.0, 0.0, -10.0, 1.0), zm.f32x4(0.0, 0.0, 0.0, 1.0), zm.f32x4(0.0, 1.0, 0.0, 0.0));
        var projMtx: zm.Mat = undefined;
        const aspect_ratio = @as(f32, @floatFromInt(viewport.width)) / @as(f32, @floatFromInt(viewport.height));
        projMtx = zm.perspectiveFovRhGl(
            0.25 * std.math.pi,
            aspect_ratio,
            0.1,
            100.0,
        );

        return Renderer{
            .allocator = allocator,
            .viewport = viewport,
            .program = program,
            .vbh = vbh,
            .white_texture = Image.initSingleColor(0, 0, 0, 0),
            .ibh = ibh,
            .vertex_layout = layout,
            .view_mtx = viewMtx,
            .proj_mtx = projMtx,
            .accum_time = 0.0,
        };
    }

    pub fn draw(self: *Renderer) void {
        self.accum_time += 1;
        if (self.accum_time > 180000) {
            self.accum_time = 0.0;
        }
        bgfx.setViewClear(0, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030ff, 1.0, 0.0);
        bgfx.setViewRect(0, 0, 0, @intCast(self.viewport.width), @intCast(self.viewport.height));

        bgfx.setViewTransform(0, &math.matToArr(self.view_mtx), &math.matToArr(self.proj_mtx));
        const model_mtx = zm.rotationY(self.accum_time / 1000);
        _ = bgfx.setTransform(&math.matToArr(zm.transpose(model_mtx)), 1);

        bgfx.setVertexBuffer(0, self.vbh, 0, cube_vertices.len);
        bgfx.setIndexBuffer(self.ibh, 0, cube_indices.len);

        const state = bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA |
            bgfx.StateFlags_WriteZ |
            bgfx.StateFlags_DepthTestLess;

        bgfx.setState(state, 0);

        // The submit call consumes the transform set above
        _ = bgfx.submit(0, self.program.program_handle, 0, bgfx.DiscardFlags_All);

        _ = bgfx.frame(bgfx.FrameFlags_None);
    }
    pub fn flush(
        renderer: *Renderer,
        self: *Batcher,
        view_id: u8,
        program: bgfx.ProgramHandle,
    ) void {
        const v_count = @as(u32, @intCast(self.vertices.items.len));
        const i_count = @as(u32, @intCast(self.indices.items.len));

        if (v_count == 0) return;

        // 1. Ask bgfx for temporary space
        var tvb: bgfx.TransientVertexBuffer = undefined;
        var tib: bgfx.TransientIndexBuffer = undefined;

        bgfx.allocTransientVertexBuffer(&tvb, v_count, &renderer.layout);
        bgfx.allocTransientIndexBuffer(&tib, i_count, false);

        // 2. Copy your local Zig data into the bgfx memory
        @memcpy(tvb.data[0..(@sizeOf(Vertex) * v_count)], std.mem.sliceAsBytes(self.vertices.items));
        @memcpy(tib.data[0..(i_count * 2)], std.mem.sliceAsBytes(self.indices.items));

        // 3. Set the buffers for the draw call
        bgfx.setTransientVertexBuffer(0, &tvb, 0, v_count);
        bgfx.setTransientIndexBuffer(&tib, 0, i_count);

        // 4. Submit
        bgfx.setState(bgfx.StateFlags_Default, 0);
        _ = bgfx.submit(view_id, program, 0, bgfx.DiscardFlags_All);

        // 5. Clear local storage for next frame
        // We clear the length but keep the capacity to avoid re-allocating next frame
        self.vertices.items.len = 0;
        self.indices.items.len = 0;
    }
    pub fn draw0(self: *Renderer) void {
        bgfx.setViewClear(0, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030ff, 1.0, 0.0);
        bgfx.setViewRect(0, 0, 0, @intCast(self.viewport.width), @intCast(self.viewport.height));
        bgfx.touch(0);

        bgfx.setViewTransform(0, &math.matToArr(self.view_mtx), &math.matToArr(self.proj_mtx));

        bgfx.setVertexBuffer(0, self.vbh, 0, cube_vertices.len);
        bgfx.setIndexBuffer(self.ibh, 0, cube_indices.len);
        const state = bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA |
            bgfx.StateFlags_WriteZ |
            bgfx.StateFlags_DepthTestLess;
        bgfx.setState(state, 0);

        bgfx.submit(0, self.program.program_handle, 0, bgfx.DiscardFlags_All);
        _ = bgfx.frame(bgfx.FrameFlags_None);
    }

    pub fn deinit(self: *Renderer) void {
        self.program.deinit();
        self.white_texture.deinit();
        bgfx.destroyVertexBuffer(self.vbh);
        bgfx.destroyIndexBuffer(self.ibh);
        bgfx.shutdown();
    }
};
