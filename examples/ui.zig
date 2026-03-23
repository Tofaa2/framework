const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var alloc_provider = runtime.App.DefaultAllocatorProvider.init();
    defer alloc_provider.deinit();
    const allocators = alloc_provider.interface();
    var app = runtime.App.init(.{
        .name = "ui",
        .allocators = allocators,
    });
    defer app.deinit();


    const font = try app.assets.loadFont("assets/Roboto-Regular.ttf", 32, 512);
    app.resources.add(
        runtime.ui.UIContext.init(
            app.allocators.generic,
            font, app.renderer.getView(.@"2d").?,
        ),
    ) catch unreachable;
    app.scheduler.addStage(.{
        .name = "draw-ui",
        .phase = .render,
        .run = drawUi,
        .priority = 100,
    }) catch unreachable;

    app.run();
}

fn drawUi(app: *runtime.App) void {
    var ctx = app.resources.getMut(runtime.ui.UIContext).?;
    
    ctx.begin(&app.window);
    defer ctx.end(&app.assets);

    ctx.rect(100, 100, 100, 100, .red);
    if (ctx.button(&app.assets, "Hello, World", 100, 100, 20, 20)) {
        std.debug.print("BUTTON CLICKED\n", .{});
    }
}
