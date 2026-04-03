const Skybox = @This();
const Color = @import("../components/Color.zig");
const root = @import("../root.zig");


pub const SkyboxMode = union(enum) {
    gradient: struct {
        top_color: root.Color = .{ .r = 50, .g = 120, .b = 200, .a = 255 },
        bottom_color: root.Color = .{ .r = 150, .g = 200, .b = 255, .a = 255 },
    },
    texture: struct {
        image: root.Handle(root.Image),
    },
    // cubemap: struct {
    //     cubemap: root.Handle(root.Cubemap),
    // },
};

mode: SkyboxMode,
