const runtime = @import("runtime");
pub const window = @import("window");
pub const api = @import("window");
const log = @import("std").log.scoped(.window);
pub const Plugin = struct {
    pub fn init(self: *Plugin, context: *runtime.App, config: anytype) void {
        _ = self;
        const w = window.Window.init(config.title, config.width, config.height);
        context.resources.add(w) catch unreachable;

        context.scheduler.addStage(.{
            .name = "window-update",
            .run = struct {
                fn func(a: *runtime.App) void {
                    var state = a.resources.getMut(window.Window).?;
                    state.update();
                    a.running = state.shouldClose() == false;
                }
            }.func,
            .phase = .update,
        }) catch unreachable;
        context.resources.getMut(window.Window).?.setupCallbacks();
        context.resources.getMut(window.Window).?.setData(0, context);
        log.info("Window Plugin Initialized: Native PTR: {any}", .{@constCast(&w).getNativePtr()});
    }

    pub fn deinit(_: *Plugin, context: *runtime.App) void {
        const w = context.resources.get(window.Window);
        if (w) |win| {
            @constCast(win).deinit();
        }
    }
};
