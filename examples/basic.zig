const runtime = @import("runtime");
const std = @import("std");

pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var app = runtime.App.init(.{
        .name = "snake",
        .allocators = .{
            .frame = arena_allocator,
            .generic = allocator,
            .world = allocator,
            .frame_arena = arena,
        },
    });
    defer app.deinit();

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();

    const circle = app.world.create();
    app.world.add(circle, runtime.primitive.Transform {});
    app.world.add(circle, runtime.primitive.Anchor { .point =  .center });
    app.world.add(circle, runtime.primitive.Renderable {
        .circle = .{ .radius = 100, .segments = 128 },
    });
    app.run();
}
