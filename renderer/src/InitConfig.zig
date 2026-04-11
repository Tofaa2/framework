const Self = @This();
const bgfx = @import("bgfx").bgfx;
const builtin = @import("builtin");
const Allocator = @import("std").mem.Allocator;

allocator: Allocator,
debug: bool = builtin.mode == .Debug,
nwh: ?*anyopaque,
ndt: ?*anyopaque,
renderer: bgfx.RendererType = .Count,
