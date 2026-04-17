/// Low-level Renderer — wraps Context + a fixed view array.
/// High-level users should prefer RenderWorld. This exists for power users
/// who want to manage views manually without the full high-level pipeline.
const Renderer = @This();
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const Context = @import("Context.zig");
const Allocator = std.mem.Allocator;
const errors = @import("errors.zig");
const View = @import("View.zig");

pub const MAX_VIEWS: u16 = 32;

allocator: Allocator,
context: Context,
views: [MAX_VIEWS]View,

pub fn init(allocator: Allocator, context_config: Context.Config) errors.Init!Renderer {
    var self: Renderer = undefined;
    self.allocator = allocator;
    self.context   = try Context.init(context_config);
    for (0..MAX_VIEWS) |i| self.views[i] = View.init(@intCast(i));
    return self;
}

pub fn getView(self: *Renderer, index: u16) ?*View {
    if (index >= MAX_VIEWS) return null;
    return &self.views[index];
}

pub fn setView(self: *Renderer, view: View) void {
    const id = view.id;
    if (id >= MAX_VIEWS) std.debug.panic("View id out of range: {}", .{id});
    self.views[id] = view;
}

pub fn frame(_: *Renderer) void {
    _ = bgfx.frame(bgfx.FrameFlags_None);
}

pub fn deinit(self: *Renderer) void {
    self.context.deinit();
}
