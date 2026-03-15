const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const math = @import("math");

const Self = @This();

transform: math.Mat4x4,
texture: bgfx.TextureHandle,
start_index: usize,
number_of_indices: usize,
depth: usize,
stencil: usize,
