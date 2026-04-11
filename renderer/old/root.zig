pub const bgfx = @import("bgfx").bgfx;
pub const zbgfx = @import("bgfx");
pub const shaders = @import("shader_module");
pub const zmesh = @import("zmesh");
pub const math = @import("math.zig");
pub const tangents = @import("tangents.zig");

const std = @import("std");
const core = @import("core.zig");
const resources = @import("resources_new.zig");
const material = @import("material_new.zig");
const renderer = @import("renderer_new.zig");
const post = @import("post_processor.zig");
pub const ibl = @import("ibl.zig");

pub const Vertex = core.Vertex;
pub const Color = core.Color;
pub const Vec2 = core.Vec2;
pub const Vec3 = core.Vec3;
pub const Vec4 = core.Vec4;
pub const Mat4 = core.Mat4;

pub const MeshHandle = resources.MeshHandle;
pub const TextureHandle = resources.TextureHandle;
pub const ProgramHandle = resources.ProgramHandle;
pub const FramebufferHandle = resources.FramebufferHandle;

pub const Material = material.Material;
pub const DrawCall = renderer.DrawCall;
pub const Camera = renderer.Camera;
pub const Renderer = renderer.Renderer;
pub const Shape = renderer.Shape;
pub const PostProcessor = post.PostProcessor;
