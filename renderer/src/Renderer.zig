const zbgfx = @import("bgfx");
pub const bgfx = zbgfx.bgfx;
const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const bgfx_util = @import("bgfx_util.zig");
const pool = @import("pool");
const vert_parser = @import("vertex_parser.zig");
pub const errors = @import("errors.zig");
pub const zmesh = @import("zmesh");

pub const math = @import("math.zig");
pub const ShaderProgram = @import("ShaderProgram.zig");
pub const InitConfig = @import("InitConfig.zig");
pub const default_shaders = @import("shader_module");
pub const obj = @import("obj_loading.zig");
pub const VertexLayoutPool = pool.Pool(32, 16, bgfx.VertexLayout, bgfx.VertexLayout);

/// Represents a draw state attached to a view
pub const DrawState = @import("DrawState.zig");

/// View — owns its rect, clear settings, MVP, default state.
pub const View = @import("View.zig");

pub const StaticMeshHandle = StaticMeshPool.HandleType;
pub const DynamicMeshHandle = DynamicMeshPool.HandleType;

// StaticMesh — uploaded once, never updated.
pub const StaticMesh = @import("StaticMesh.zig");
/// DynamicMesh — can be updated each frame.
pub const DynamicMesh = @import("DynamicMesh.zig");
pub const StaticMeshPool = pool.Pool(32, 16, StaticMesh, StaticMesh);
pub const DynamicMeshPool = pool.Pool(32, 16, DynamicMesh, DynamicMesh);
pub const ShaderProgramPool = pool.Pool(32, 16, ShaderProgram, ShaderProgram);

const Renderer = @This();

// Renderer
allocator: Allocator,
static_meshes: StaticMeshPool,
dynamic_meshes: DynamicMeshPool,
shaders: ShaderProgramPool,

pub fn init(self: *Renderer, config: InitConfig) errors.Init!void {
    var bx_init = std.mem.zeroes(bgfx.Init);
    bgfx.initCtor(&bx_init);
    bx_init.type = config.renderer;
    bx_init.platformData.ndt = config.ndt;
    bx_init.platformData.nwh = config.nwh;
    bx_init.debug = config.debug;
    bx_init.callback = &bgfx_util.bgfx_clbs;

    if (!bgfx.init(&bx_init)) return errors.Init.BgfxInitFailed;

    if (config.debug) bgfx.setDebug(bgfx.DebugFlags_Stats);

    self.* = .{
        .allocator = config.allocator,
        .static_meshes = StaticMeshPool.init(config.allocator, 32) catch return errors.Init.OutOfMemory,
        .dynamic_meshes = DynamicMeshPool.init(config.allocator, 32) catch return errors.Init.OutOfMemory,
        .shaders = ShaderProgramPool.init(config.allocator, 32) catch return errors.Init.OutOfMemory,
    };
}

pub fn deinit(self: *Renderer) void {
    // Destroy all live meshes before shutdown
    self.static_meshes.forEachMut(struct {
        fn f(_: StaticMeshPool.HandleType, m: *StaticMesh) void {
            m.deinit();
        }
    }.f);
    self.dynamic_meshes.forEachMut(struct {
        fn f(_: DynamicMeshPool.HandleType, m: *DynamicMesh) void {
            m.deinit();
        }
    }.f);
    self.shaders.forEachMut(struct {
        fn f(_: ShaderProgramPool.HandleType, s: *ShaderProgram) void {
            s.deinit();
        }
    }.f);
    bgfx.shutdown();
}

// ---- Mesh creation ----

pub fn createStaticMesh(
    self: *Renderer,
    comptime Vertex: type,
    comptime info: vert_parser.VertexInfo(Vertex),
    vertices: []const Vertex,
    indices: []const u16,
) StaticMeshHandle {
    const layout = vert_parser.createLayout(Vertex, info, bgfx.getRendererType());

    const vbh = bgfx.createVertexBuffer(
        bgfx.makeRef(vertices.ptr, @intCast(vertices.len * @sizeOf(Vertex))),
        &layout,
        bgfx.BufferFlags_None,
    );
    const ibh = bgfx.createIndexBuffer(
        bgfx.makeRef(indices.ptr, @intCast(indices.len * @sizeOf(u16))),
        bgfx.BufferFlags_None,
    );

    return self.static_meshes.add(.{
        .vbh = vbh,
        .ibh = ibh,
        .layout = layout,
    }) catch unreachable;
}

pub fn createDynamicMesh(
    self: *Renderer,
    comptime Vertex: type,
    comptime info: vert_parser.VertexInfo(Vertex),
    initial_vertices: []const Vertex,
    initial_indices: []const u16,
) DynamicMeshHandle {
    const layout = vert_parser.createLayout(Vertex, info, bgfx.getRendererType());

    const vbh = bgfx.createDynamicVertexBufferMem(
        bgfx.copy(initial_vertices.ptr, @intCast(initial_vertices.len * @sizeOf(Vertex))),
        &layout,
        bgfx.BufferFlags_None,
    );
    const ibh = bgfx.createDynamicIndexBufferMem(
        bgfx.copy(initial_indices.ptr, @intCast(initial_indices.len * @sizeOf(u16))),
        bgfx.BufferFlags_None,
    );

    return self.dynamic_meshes.add(.{
        .vbh = vbh,
        .ibh = ibh,
        .layout = layout,
        .vertex_count = @intCast(initial_vertices.len),
        .index_count = @intCast(initial_indices.len),
    }) catch unreachable;
}

// ---- Mesh update (dynamic only) ----
pub fn updateDynamicMesh(
    self: *Renderer,
    handle: DynamicMeshHandle,
    comptime Vertex: type,
    vertices: []const Vertex,
    indices: []const u16,
) void {
    const mesh = self.dynamic_meshes.getPtr(handle);
    bgfx.updateDynamicVertexBuffer(
        mesh.vbh,
        0,
        bgfx.copy(vertices.ptr, @intCast(vertices.len * @sizeOf(Vertex))),
    );
    bgfx.updateDynamicIndexBuffer(
        mesh.ibh,
        0,
        bgfx.copy(indices.ptr, @intCast(indices.len * @sizeOf(u16))),
    );
    mesh.vertex_count = @intCast(vertices.len);
    mesh.index_count = @intCast(indices.len);
}

// ---- Mesh destroy ----
pub fn destroyStaticMesh(self: *Renderer, handle: StaticMeshHandle) void {
    if (self.static_meshes.getPtr(handle)) |m| {
        m.deinit();
        self.static_meshes.remove(handle);
    }
}

pub fn destroyDynamicMesh(self: *Renderer, handle: DynamicMeshHandle) void {
    if (self.dynamic_meshes.getPtr(handle)) |m| {
        m.deinit();
        self.dynamic_meshes.remove(handle);
    }
}

// ---- Shader ----

pub fn createShader(self: *Renderer, shader: ShaderProgram) ShaderProgramPool.HandleType {
    return self.shaders.add(shader) catch unreachable;
}

// ---- Draw calls ----

pub fn drawToView(
    self: *Renderer,
    view: *const View,
    mesh: StaticMeshHandle,
    shader: ShaderProgramPool.HandleType,
    transform: *const [16]f32,
    state_override: ?DrawState,
) void {
    const m = self.static_meshes.get(mesh) orelse return;
    const s = self.shaders.get(shader) orelse return;
    const st = state_override orelse view.default_state;

    _ = bgfx.setTransform(transform, 1);
    bgfx.setState(st.state_flags, st.blend_rgba);
    bgfx.setVertexBuffer(0, m.vbh, 0, std.math.maxInt(u32));
    bgfx.setIndexBuffer(m.ibh, 0, std.math.maxInt(u32));
    _ = bgfx.submit(view.id, s.program_handle, 0, bgfx.DiscardFlags_All);
}

pub fn drawDynamicToView(
    self: *Renderer,
    view: *const View,
    mesh: DynamicMeshHandle,
    shader: ShaderProgramPool.HandleType,
    transform: *const [16]f32,
    state_override: ?DrawState,
) void {
    const m = self.dynamic_meshes.get(mesh);
    const s = self.shaders.get(shader);
    const st = state_override orelse view.default_state;

    _ = bgfx.setTransform(transform, 1);
    bgfx.setState(st.state_flags, st.blend_rgba);
    bgfx.setDynamicVertexBuffer(0, m.vbh, 0, m.vertex_count);
    bgfx.setDynamicIndexBuffer(m.ibh, 0, m.index_count);
    _ = bgfx.submit(view.id, s.program_handle, 0, bgfx.DiscardFlags_All);
}

pub fn drawTransient(
    self: *Renderer,
    view: *const View,
    comptime Vertex: type,
    comptime info: vert_parser.VertexInfo(Vertex),
    vertices: []const Vertex,
    indices: []const u16,
    shader: ShaderProgramPool.HandleType,
    transform: *const [16]f32,
    state_override: ?DrawState,
) void {
    const layout = vert_parser.createLayout(Vertex, info, bgfx.getRendererType());
    const st = state_override orelse view.default_state;

    var tvb: bgfx.TransientVertexBuffer = undefined;
    var tib: bgfx.TransientIndexBuffer = undefined;

    if (!bgfx.allocTransientBuffers(
        &tvb,
        &layout,
        @intCast(vertices.len),
        &tib,
        @intCast(indices.len),
        false,
    )) return; // out of transient memory — silently skip

    @memcpy(
        @as([*]Vertex, @ptrCast(@alignCast(tvb.data)))[0..vertices.len],
        vertices,
    );
    @memcpy(
        @as([*]u16, @ptrCast(@alignCast(tib.data)))[0..indices.len],
        indices,
    );

    const s = self.shaders.get(shader);
    _ = bgfx.setTransform(transform, 1);
    bgfx.setState(st.state_flags, st.blend_rgba);
    bgfx.setTransientVertexBuffer(0, &tvb, 0, @intCast(vertices.len));
    bgfx.setTransientIndexBuffer(&tib, 0, @intCast(indices.len));
    _ = bgfx.submit(view.id, s.program_handle, 0, bgfx.DiscardFlags_All);
}

pub fn getRendererType(self: *Renderer) bgfx.RendererType {
    _ = self;
    return bgfx.getRendererType();
}

pub fn frame(self: *Renderer) void {
    _ = self;

    _ = bgfx.frame(bgfx.FrameFlags_None);
}
