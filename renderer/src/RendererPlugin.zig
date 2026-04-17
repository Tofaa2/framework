/// Orin engine plugin for the renderer.
/// Wires RenderWorld into App as an owned resource and registers a render-phase system.
///
/// Usage:
///   var app = try orin.App.init(allocator, .{ .name = "my_game" });
///   // WindowPlugin must already be registered so WindowResource is available.
///   app.addPlugin(renderer.RendererPlugin);
///   app.run();
///
/// In user systems, retrieve the RenderWorld via:
///   const rw = world.getMutResource(renderer.RenderWorld).?;
const std = @import("std");
const orin = @import("orin");
const rgfw = @import("rgfw");
const zmesh = @import("zmesh");
const RenderWorld = @import("RenderWorld.zig");

pub const RendererPlugin = struct {
    pub const name = "RendererPlugin";

    pub fn build(app: *orin.App) void {
        // Retrieve the RGFW window registered by WindowPlugin.
        // WindowPlugin must call: app.world.insertResource(window_ptr)
        const window = app.world.getMutResource(rgfw.Window) orelse
            @panic("RendererPlugin requires WindowPlugin to be registered first");

        // Initialize zmesh for model loading
        zmesh.init(app.allocator);

        const rw = RenderWorld.init(app.allocator, .{
            .nwh    = window.getNativePtr(),
            .ndt    = window.getNativeNdt(),
            .width  = window.width,
            .height = window.height,
        }) catch @panic("RendererPlugin: RenderWorld init failed");

        app.world.insertOwnedResource(RenderWorld, rw);

        app.addSystem(beginFrameSystem).inPhase(.pre_update).commit();
        app.addSystem(endFrameSystem).inPhase(.render).commit();
    }

    pub fn deinit(app: *orin.App) void {
        if (app.world.getMutResource(RenderWorld)) |rw| {
            rw.deinit();
        }
        zmesh.deinit();
    }
};

// ---- Systems ----------------------------------------------------------------

/// Runs at the start of every tick — clears draw lists, sets up views.
fn beginFrameSystem(world: *orin.World) void {
    const rw = world.getMutResource(RenderWorld) orelse return;

    // Handle window resize
    const win = world.getMutResource(rgfw.Window) orelse return;
    if (win.resized_last_frame) {
        rw.resize(win.width, win.height);
        win.resized_last_frame = false;
    }

    rw.beginFrame();
}

/// Runs at the end of every tick — submits all draw calls and advances the bgfx frame.
fn endFrameSystem(world: *orin.World) void {
    const rw = world.getMutResource(RenderWorld) orelse return;
    rw.endFrame();
}
