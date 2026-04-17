const c = @import("c.zig").c;

const std = @import("std");
const enums = @import("enums.zig");

pub const Event = union(enum) {
    none,
    quit,
    key_pressed: KeyEvent,
    key_released: KeyEvent,
    key_char: u32,
    mouse_button_pressed: MouseButtonEvent,
    mouse_button_released: MouseButtonEvent,
    mouse_scroll: MouseScrollEvent,
    mouse_motion: MouseMotionEvent,
    window_moved: [2]i32,
    window_resized: [2]u32,
    focus_in,
    focus_out,
    mouse_enter,
    mouse_leave,
    window_refresh,
    window_maximized,
    window_minimized,
    window_restored,
    scale_updated: [2]f32,
    data_drop: DataDrop,
    data_drag: [2]i32,
    monitor_connected,
    monitor_disconnected,
    unknown,

    pub const KeyEvent = struct {
        key: enums.Key,
        repeat: bool,
        mod: enums.Keymod, // You can further wrap RGFW_keymod if needed

    };

    pub const MouseButtonEvent = struct {
        button: enums.MouseButton,
        x: i32,
        y: i32,
    };

    pub const MouseScrollEvent = struct {
        x: f32,
        y: f32,
    };

    pub const MouseMotionEvent = struct {
        x: i32,
        y: i32,
        delta_x: f32,
        delta_y: f32,
    };

    pub const DataDrop = struct {
        x: i32,
        y: i32,
        count: usize,
        files_ptr: [*]const [*c]const u8,

        /// Helper to get a specific file path as a Zig slice
        pub fn getPath(self: DataDrop, index: usize) []const u8 {
            if (index >= self.count) @panic("Index out of bounds");
            return std.mem.span(self.files_ptr[index]);
        }
    };
};

pub fn fromRGFW(c_ev: c.RGFW_event) Event {
    return switch (c_ev.type) {
        c.RGFW_eventNone => .none,
        c.RGFW_quit => .quit,

        c.RGFW_keyPressed, c.RGFW_keyReleased => {
            const ev = Event.KeyEvent{
                .key = @enumFromInt(c_ev.key.value),
                .repeat = c_ev.key.repeat != 0,
                .mod = @as(enums.Keymod, @bitCast(@as(u8, @intCast(c_ev.key.mod)))),
            };
            return if (c_ev.type == c.RGFW_keyPressed) .{ .key_pressed = ev } else .{ .key_released = ev };
        },

        c.RGFW_keyChar => .{ .key_char = c_ev.keyChar.value },

        c.RGFW_mouseButtonPressed, c.RGFW_mouseButtonReleased => {
            const ev = Event.MouseButtonEvent{
                .button = @enumFromInt(c_ev.button.value),
                .x = c_ev.mouse.x, // RGFW mouse pos is often in the mouse struct
                .y = c_ev.mouse.y,
            };
            return if (c_ev.type == c.RGFW_mouseButtonPressed) .{ .mouse_button_pressed = ev } else .{ .mouse_button_released = ev };
        },

        c.RGFW_mouseScroll => .{ .mouse_scroll = .{ .x = c_ev.scroll.x, .y = c_ev.scroll.y } },

        c.RGFW_mousePosChanged => .{ .mouse_motion = .{
            .x = c_ev.mouse.x,
            .y = c_ev.mouse.y,
            .delta_x = c_ev.mouse.vecX,
            .delta_y = c_ev.mouse.vecY,
        } },

        c.RGFW_windowMoved => .{ .window_moved = .{ c_ev.mouse.x, c_ev.mouse.y } },

        c.RGFW_focusIn => .focus_in,
        c.RGFW_focusOut => .focus_out,
        c.RGFW_mouseEnter => .mouse_enter,
        c.RGFW_mouseLeave => .mouse_leave,
        c.RGFW_windowRefresh => .window_refresh,
        c.RGFW_windowMaximized => .window_maximized,
        c.RGFW_windowMinimized => .window_minimized,
        c.RGFW_windowRestored => .window_restored,

        c.RGFW_scaleUpdated => .{ .scale_updated = .{ c_ev.scale.x, c_ev.scale.y } },

        c.RGFW_dataDrag => .{ .data_drag = .{ c_ev.drag.x, c_ev.drag.y } },
        c.RGFW_windowResized => {
            var w: i32 = 0;
            var h: i32 = 0;
            _ = c.RGFW_window_getSize(c_ev.common.win, &w, &h);

            return .{ .window_resized = .{ @intCast(w), @intCast(h) } };
        },
        c.RGFW_dataDrop => .{
            .data_drop = .{
                .x = c_ev.mouse.x,
                .y = c_ev.mouse.y,
                .count = c_ev.drop.count,
                .files_ptr = @ptrCast(c_ev.drop.files), // TODO: Sus
            },
        },

        else => .unknown,
    };
}
