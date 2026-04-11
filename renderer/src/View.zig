const View = @This();
const bgfx = @import("bgfx").bgfx;
const DrawState = @import("DrawState.zig");
const math = @import("math.zig");

id: bgfx.ViewId,
rect: Rect,
clear: ClearState,
model: [16]f32,
view: [16]f32,
projection: [16]f32,
default_state: DrawState,

pub const Rect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,
};

pub const ClearState = struct {
    flags: u16 = bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth,
    color: u32 = 0x000000ff,
    depth: f32 = 1.0,
    stencil: u8 = 0,
};

pub fn init(id: bgfx.ViewId, rect: Rect, default_state: DrawState) View {
    return .{
        .id = id,
        .rect = rect,
        .clear = .{},
        .model = math.identityArr(),
        .view = math.identityArr(),
        .projection = math.identityArr(),
        .default_state = default_state,
    };
}

// Call once per frame before submitting draws.
pub fn apply(self: *const View) void {
    bgfx.setViewRect(
        self.id,
        self.rect.x,
        self.rect.y,
        self.rect.width,
        self.rect.height,
    );
    bgfx.setViewClear(
        self.id,
        self.clear.flags,
        self.clear.color,
        self.clear.depth,
        self.clear.stencil,
    );
    bgfx.setViewTransform(self.id, &self.view, &self.projection);
    bgfx.touch(self.id);
}

pub fn onResize(self: *View, width: u16, height: u16) void {
    self.rect.width = width;
    self.rect.height = height;
}

pub fn setModel(self: *View, m: [16]f32) void {
    self.model = m;
}
pub fn setViewMtx(self: *View, v: [16]f32) void {
    self.view = v;
}
pub fn setProjection(self: *View, p: [16]f32) void {
    self.projection = p;
}
