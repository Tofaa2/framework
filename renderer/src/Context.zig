const Context = @This();
const std = @import("std");
const bgfx = @import("bgfx").bgfx;

const bgfx_util = @import("bgfx_util.zig");
const errors = @import("errors.zig");

width: u32,
height: u32,
reset_flags: u32,

pub const AaMode = enum {
    none,
    msaa2x,
    msaa4x,
    msaa8x,
    msaa16x,
};

fn aaModeToFlags(mode: AaMode) u32 {
    return switch (mode) {
        .none => bgfx.ResetFlags_None,
        .msaa2x => bgfx.ResetFlags_MsaaX2,
        .msaa4x => bgfx.ResetFlags_MsaaX4,
        .msaa8x => bgfx.ResetFlags_MsaaX8,
        .msaa16x => bgfx.ResetFlags_MsaaX16,
    };
}

pub const Config = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    ndt: ?*anyopaque,
    nwh: ?*anyopaque,
    renderer: bgfx.RendererType = bgfx.RendererType.Count,
    debug: bool = false,
    aa_mode: AaMode = .none,
};

pub fn init(config: Config) errors.Init!Context {
    const reset_flags = aaModeToFlags(config.aa_mode);
    var bx_init = std.mem.zeroes(bgfx.Init);
    bgfx.initCtor(&bx_init);
    bx_init.type = config.renderer;
    bx_init.platformData.ndt = config.ndt;
    bx_init.platformData.nwh = config.nwh;
    bx_init.debug = config.debug;
    bx_init.callback = &bgfx_util.bgfx_clbs;
    bx_init.resolution.width = config.width;
    bx_init.resolution.height = config.height;
    bx_init.resolution.reset = reset_flags;

    if (!bgfx.init(&bx_init)) return errors.Init.BgfxInitFailed;
    if (config.debug) bgfx.setDebug(bgfx.DebugFlags_Stats);

    return .{
        .width = config.width,
        .height = config.height,
        .reset_flags = reset_flags,
    };
}

pub fn resize(self: *Context, width: u32, height: u32) void {
    self.width = width;
    self.height = height;
    bgfx.reset(width, height, self.reset_flags, .RGBA8);
}

pub fn setAaMode(self: *Context, mode: AaMode) void {
    self.reset_flags = aaModeToFlags(mode);
    bgfx.reset(self.width, self.height, self.reset_flags, .RGBA8);
}

pub fn frame(self: *Context) void {
    _ = self;
    _ = bgfx.frame(bgfx.FrameFlags_None);
}

pub fn deinit(self: *Context) void {
    _ = self;
    bgfx.shutdown();
}

pub fn getRendererType(self: *Context) bgfx.RendererType {
    _ = self;
    return bgfx.getRendererType();
}
