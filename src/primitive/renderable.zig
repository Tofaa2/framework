const Image = @import("Image.zig");
const Font = @import("Font.zig");
const std = @import("std");
const App = @import("../App.zig");
const Mesh = @import("../renderer/Mesh.zig");
const Handle = @import("../core/AssetPool.zig").Handle;
pub const Renderable = union(enum) {
    circle: struct {
        radius: f32,
        segments: ?u32 = null,
    },
    rect: struct {
        width: f32,
        height: f32,
    },
    sprite: struct {
        image: Handle(Image),
        uv: ?struct { u0: f32, v0: f32, u1: f32, v1: f32 } = null,
    },
    text: struct {
        font: Handle(Font),
        content: []const u8,
    },
    fmt_text: struct {
        font: Handle(Font),
        buf: []u8, // caller-provided buffer, no allocation needed
        len: usize = 0, // current length of formatted text
        format_fn: *const fn (buf: []u8, app: *App) []u8,
    },
    mesh: struct {
        mesh: Handle(Mesh),
    },
};
