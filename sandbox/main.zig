const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = runtime.App.init(.{ .name = "sandbox", .allocators = .{ .frame = allocator, .generic = allocator, .world = allocator } });
    defer app.deinit();

    const shinoa = runtime.primitive.Image.initFile("assets/shinoa.png");
    defer shinoa.deinit();

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();

    const circle = app.world.create();
    // app.world.add(circle, runtime.primitive.Renderable{ .sprite = .{ .image = &font.atlas } });

    const shinoa_image = app.world.create();
    app.world.add(shinoa_image, runtime.primitive.Renderable{ .sprite = .{ .image = &shinoa } });
    app.world.add(shinoa_image, runtime.primitive.Transform{
        .center = .{ 300.0, 100.0, 0.0 },
    });

    app.world.add(circle, runtime.primitive.Renderable{ .text = .{
        .content = "hELLO, BEANS",
        .font = &font,
    } });
    app.world.add(circle, runtime.primitive.Transform{
        .center = .{ 960.0, 540.0, 0.0 },
    });
    app.run();
}
