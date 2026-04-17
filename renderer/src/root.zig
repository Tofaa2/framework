// ---- Low-level primitives ---------------------------------------------------
pub const bgfx = @import("bgfx").bgfx;
pub const Context = @import("Context.zig");
pub const View = @import("View.zig");
pub const ShaderProgram = @import("ShaderProgram.zig");
pub const Framebuffer = @import("Framebuffer.zig");
pub const Texture = @import("Texture.zig");
pub const UniformStore = @import("UniformStore.zig");
pub const DrawEncoder = @import("DrawEncoder.zig");
pub const vertex_parser = @import("vertex_parser.zig");
pub const errors = @import("errors.zig");

// ---- Geometry & camera ------------------------------------------------------
pub const Mesh = @import("Mesh.zig");
pub const MeshLoader = @import("MeshLoader.zig");
pub const Camera = @import("Camera.zig");
pub const Material = @import("Material.zig");
pub const lights = @import("lights.zig");
pub const env_map = @import("env_map.zig");

// ---- High-level API ---------------------------------------------------------
pub const RenderWorld = @import("RenderWorld.zig");
pub const DrawList = @import("DrawList.zig");
pub const Batch2D = @import("Batch2D.zig");
pub const PostProcess = @import("PostProcess.zig");
pub const RenderGraph = @import("RenderGraph.zig");

// ---- Orin engine plugin -----------------------------------------------------
pub const RendererPlugin = @import("RendererPlugin.zig").RendererPlugin;

// ---- Shaders (for post-processing) -----------------------------------------
pub const shaders = @import("shader_module");
