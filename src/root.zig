const std = @import("std");
const testing = std.testing;
const text = @import("text.zig");
const ioutil = @import("io.zig");
const rl = @import("raylib");

// Raylib Constants
pub const Color = rl.Color;
pub const Vec2 = rl.Vector2;
pub const Camera = rl.Camera2D;

// Framework Constants
pub const FontRenderer = text.FontRenderer;

var state: EngineState = undefined;
pub const EngineState = struct {
    close_requested: bool,
    font_renderer: FontRenderer,
    io: ioutil.Io,
    allocator: std.mem.Allocator
};

pub fn io() ioutil.Io {
    return state.io;
}

pub fn closeRequested() bool {
    return state.close_requested;
}

pub fn defaultFontRenderer() FontRenderer {
    return state.font_renderer;
}

pub fn backingAllocator() std.mem.Allocator {
    return state.allocator;
}

pub fn beginRendering() void {
    state.close_requested = rl.windowShouldClose();
    rl.beginDrawing();
}

pub fn flushRendering() void {
    rl.endDrawing();
}

pub fn init(
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    title: [*:0]const u8
) !void {
    state = .{
        .close_requested = false,
        .allocator = allocator,
        .font_renderer = try FontRenderer.init(allocator),
        .io = .{
            .allocator = allocator
        }
    };
    rl.initWindow(width, height, title);
}

pub fn deinit() void {
    rl.closeWindow();
}
