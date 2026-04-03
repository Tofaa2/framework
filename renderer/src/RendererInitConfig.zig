const bgfx = @import("bgfx");
const builtin = @import("builtin");
const std = @import("std");

ndt: ?*anyopaque,
nwh: ?*anyopaque,
width: u32,
height: u32,
type: bgfx.bgfx.RendererType = .Count,

allocator: std.mem.Allocator,
debug: bool = builtin.mode == .Debug,
