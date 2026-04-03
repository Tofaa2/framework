/// Union representing different types of primitives that can be rendered.
/// Components are tagged by their rendering operation type.
const Image = @import("../assets/Image.zig");
const Font = @import("../assets/Font.zig");
const std = @import("std");
const App = @import("../core/App.zig");
const Mesh = @import("../renderer/Mesh.zig");
const Handle = @import("../core/AssetPool.zig").Handle;

pub const Renderable = union(enum) {
    /// Renders a simple 2D circle.
    circle: struct {
        radius: f32,
        segments: ?u32 = null,
    },
    /// Renders a 2D rectangle.
    rect: struct {
        width: f32,
        height: f32,
    },
    /// Renders a 2D image or atlas region.
    sprite: struct {
        image: Handle(Image),
        uv: ?struct { u0: f32, v0: f32, u1: f32, v1: f32 } = null,
    },
    /// Renders static 2D text using a font asset.
    text: struct {
        font: Handle(Font),
        content: []const u8,
    },
    /// Renders dynamic, formatted 2D text updated every frame.
    fmt_text: struct {
        font: Handle(Font),
        /// Preallocated buffer for the formatted text.
        buf: []u8, // caller-provided buffer, no allocation needed
        /// Current length of the formatted text in the buffer.
        len: usize = 0, // current length of formatted text
        /// Callback function to update the buffer content.
        format_fn: *const fn (buf: []u8, app: *App) []u8,
    },
    /// Renders a 3D mesh asset.
    mesh: struct {
        mesh: Handle(Mesh),
    },
};
