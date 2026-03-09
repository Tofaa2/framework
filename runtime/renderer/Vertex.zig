const Vertex = @This();
const bgfx = @import("bgfx.zig");

x: f32,
y: f32,
z: f32,
u: f32,
v: f32,
abgr: u32,

var layout: bgfx.VertexLayout = undefined;

pub fn initLayout() void {
    _ = layout.begin(.Noop);
    _ = layout.add(.Position, 3, .Float, false, false);
    _ = layout.add(.TexCoord0, 2, .Float, false, false);
    _ = layout.add(.Color0, 4, .Uint8, true, false);
    layout.end();
}
