const std = @import("std");
const runtime = @import("../root.zig");

const MeshBuilder = @import("../renderer/MeshBuilder.zig");
const Font = @import("../primitive/Font.zig");
const Color = @import("../primitive/Color.zig");
const View = @import("../renderer/View.zig");

pub const UIContext = struct {
    geo: MeshBuilder,
    text: MeshBuilder,
    font: *const Font,
    view: *View,
    mouse_x: f32,
    mouse_y: f32,
    mouse_pressed: bool,
    mouse_down: bool,
    mouse_released: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, font: *const Font, view: *View) UIContext {
        return .{
            .geo = MeshBuilder.init(allocator),
            .text = MeshBuilder.init(allocator),
            .font = font,
            .view = view,
            .mouse_x = 0,
            .mouse_y = 0,
            .mouse_pressed = false,
            .mouse_down = false,
            .mouse_released = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UIContext) void {
        self.geo.deinit();
        self.text.deinit();
    }

    pub fn begin(self: *UIContext, win: anytype) void {
        const mouse = win.getMouse();
        self.mouse_x = @floatFromInt(mouse.x);
        self.mouse_y = @floatFromInt(mouse.y);
        self.mouse_pressed = win.isMousePressed(.left);
        self.mouse_down = win.isMouseDown(.left);
        self.mouse_released = win.isMouseReleased(.left);
        self.geo.reset();
        self.text.reset();
    }

    pub fn end(self: *UIContext) void {
        std.debug.print("geo vertices: {d} text vertices: {d}\n", .{ self.geo.vertices.items.len, self.text.vertices.items.len });
        self.geo.submitTransient(self.view, null, null, null, false);
        self.text.submitTransient(self.view, null, &self.font.atlas, null, true);
    }

    pub fn rect(self: *UIContext, x: f32, y: f32, w: f32, h: f32, color: Color) void {
        self.geo.pushRect(x, y, w, h, color);
    }

    pub fn label(self: *UIContext, text: []const u8, x: f32, y: f32, color: Color) void {
        self.text.pushText(self.font, text, x, y, color);
    }

    pub fn button(self: *UIContext, text: []const u8, x: f32, y: f32, w: f32, h: f32) bool {
        const hovered = self.mouse_x >= x and self.mouse_x <= x + w and
            self.mouse_y >= y and self.mouse_y <= y + h;
        const color = if (hovered and self.mouse_down)
            Color{ .r = 80, .g = 120, .b = 200, .a = 255 }
        else if (hovered)
            Color{ .r = 60, .g = 60, .b = 60, .a = 240 }
        else
            Color{ .r = 40, .g = 40, .b = 40, .a = 240 };

        self.geo.pushRect(x, y, w, h, color);
        self.text.pushText(self.font, text, x + 8, y + 8, .white);
        return hovered and self.mouse_released;
    }
};
