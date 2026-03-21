const runtime = @import("runtime");
const std = @import("std");

pub fn setFPSMax(application: *runtime.App, limit: ?u32) void {
    application.time.fps_limit = limit;
}


pub fn drawText(app: *runtime.App, font: *runtime.primitive.Font, content: []const u8, anchor: runtime.primitive.Anchor) void {

    const entity = app.world.create();
    app.world.add(entity, runtime.primitive.Transform {});
    app.world.add(entity, runtime.primitive.Renderable {
        .text = .{ .font = font, .content = content }
    });
    app.world.add(entity, anchor);

}
pub fn drawFPS(app: *runtime.App, font: *runtime.primitive.Font, anchor: runtime.primitive.Anchor) void {
    const fps_label = app.world.create();
    var fps_buf: [64]u8 = undefined;
    app.world.add(fps_label, runtime.primitive.Transform{
    });
    app.world.add(fps_label, runtime.primitive.Renderable{
        .fmt_text = .{
            .font = font,
            .buf = &fps_buf,
            .format_fn = struct {
                fn f(buf: []u8, a: *runtime.App) []u8 {
                    const fps = a.resources.get(runtime.primitive.FpsCounter).?.fps;
                    return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
                }
            }.f,
        },
    });

    app.world.add(fps_label, anchor);
    app.world.add(fps_label, runtime.primitive.Color.red);
}

