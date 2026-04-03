const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;
const std = @import("std");
const builtin = @import("builtin");
const bgfx_util = @import("bgfx_util.zig");
const RendererInitConfig = @import("RendererInitConfig.zig");
const Renderer = @This();
const View = @import("View.zig");

allocator: std.mem.Allocator,
views: View.Map,

pub fn flush(self: *Renderer) void {
    _ = self;
    bgfx.touch(0);
    _ = bgfx.frame(bgfx.FrameFlags_None);
}

pub fn init(self: *Renderer, config: RendererInitConfig) !void {
    var bgfx_init = std.mem.zeroes(bgfx.Init);
    bgfx.initCtor(&bgfx_init);

    bgfx_init.platformData.nwh = config.nwh;
    bgfx_init.platformData.ndt = config.ndt;
    bgfx_init.type = config.type;
    bgfx_init.resolution.width = config.width;
    bgfx_init.resolution.height = config.height;
    bgfx_init.debug = config.debug;
    bgfx_init.callback = &bgfx_util.bgfx_clbs;

    if (!bgfx.init(&bgfx_init)) {
        return error.InitFailed;
    }

    bgfx.setDebug(bgfx.DebugFlags_Stats);
    self.allocator = config.allocator;

    self.views = View.Map.init(self.allocator);
}

pub fn deinit(self: *Renderer) void {
    self.views.deinit();
}
