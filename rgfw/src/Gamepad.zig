const c = @import("c.zig").c;
const std = @import("std");
const enums = @import("enums.zig");
const Gamepad = @This();
/// Thin wrapper around a C mg_gamepad pointer.
/// Valid only while the gamepad is connected and the parent `Gamepads` is alive.
ptr: *c.mg_gamepad,

/// Null-terminated device name, e.g. "Xbox Controller".
pub fn name(self: Gamepad) [:0]const u8 {
    const bytes: [*]const u8 = @ptrCast(self.ptr);
    return std.mem.span(@as([*:0]const u8, @ptrCast(bytes + c.NAME_OFFSET)));
}

/// GUID string (SDL-compatible format).
pub fn guid(self: Gamepad) [:0]const u8 {
    const bytes: [*]const u8 = @ptrCast(self.ptr);
    return std.mem.span(@as([*:0]const u8, @ptrCast(bytes + c.GUID_OFFSET)));
}

/// Whether `button` is currently pressed (may be held from a previous frame).
pub fn isPressed(self: Gamepad, button: Button) bool {
    return c.mg_gamepad_button_is_pressed(self.ptr, button.toC());
}

/// True only on the frame the button was released.
pub fn isReleased(self: Gamepad, button: Button) bool {
    return c.mg_gamepad_button_is_released(self.ptr, button.toC());
}

/// True while the button is held down (pressed last frame AND this frame).
pub fn isHeld(self: Gamepad, button: Button) bool {
    return c.mg_gamepad_button_is_held(self.ptr, button.toC());
}

/// Axis value in the range [-1.0, 1.0].
pub fn axisValue(self: Gamepad, axis: Axis) f32 {
    return c.mg_gamepad_axis_value(self.ptr, axis.toC());
}
/// Wraps a C mg_button value.
pub const Button = enum(i8) {
    unknown = c.MG_BUTTON_UNKNOWN,
    south = c.MG_BUTTON_SOUTH,
    east = c.MG_BUTTON_EAST,
    west = c.MG_BUTTON_WEST,
    north = c.MG_BUTTON_NORTH,
    back = c.MG_BUTTON_BACK,
    guide = c.MG_BUTTON_GUIDE,
    start = c.MG_BUTTON_START,
    left_stick = c.MG_BUTTON_LEFT_STICK,
    right_stick = c.MG_BUTTON_RIGHT_STICK,
    left_shoulder = c.MG_BUTTON_LEFT_SHOULDER,
    right_shoulder = c.MG_BUTTON_RIGHT_SHOULDER,
    dpad_left = c.MG_BUTTON_DPAD_LEFT,
    dpad_right = c.MG_BUTTON_DPAD_RIGHT,
    dpad_up = c.MG_BUTTON_DPAD_UP,
    dpad_down = c.MG_BUTTON_DPAD_DOWN,
    left_trigger = c.MG_BUTTON_LEFT_TRIGGER,
    right_trigger = c.MG_BUTTON_RIGHT_TRIGGER,
    misc1 = c.MG_BUTTON_MISC1,
    right_paddle1 = c.MG_BUTTON_RIGHT_PADDLE1,
    left_paddle1 = c.MG_BUTTON_LEFT_PADDLE1,
    right_paddle2 = c.MG_BUTTON_RIGHT_PADDLE2,
    left_paddle2 = c.MG_BUTTON_LEFT_PADDLE2,
    touchpad = c.MG_BUTTON_TOUCHPAD,
    misc2 = c.MG_BUTTON_MISC2,
    misc3 = c.MG_BUTTON_MISC3,
    misc4 = c.MG_BUTTON_MISC4,
    misc5 = c.MG_BUTTON_MISC5,
    misc6 = c.MG_BUTTON_MISC6,
    _,

    /// Human-readable name, e.g. "South Button".
    pub fn name(self: Button) []const u8 {
        const ptr = c.mg_button_get_name(@intFromEnum(self));
        if (ptr) |p| return std.mem.span(p);
        return "Unknown Button";
    }

    pub fn toC(self: Button) c.mg_button {
        return @intFromEnum(self);
    }
};

/// Wraps a C mg_axis value.
pub const Axis = enum(i8) {
    unknown = c.MG_AXIS_UNKNOWN,
    left_x = c.MG_AXIS_LEFT_X,
    left_y = c.MG_AXIS_LEFT_Y,
    right_x = c.MG_AXIS_RIGHT_X,
    right_y = c.MG_AXIS_RIGHT_Y,
    left_trigger = c.MG_AXIS_LEFT_TRIGGER,
    right_trigger = c.MG_AXIS_RIGHT_TRIGGER,
    hat_dpad_left_right = c.MG_AXIS_HAT_DPAD_LEFT_RIGHT,
    hat_dpad_up_down = c.MG_AXIS_HAT_DPAD_UP_DOWN,
    throttle = c.MG_AXIS_THROTTLE,
    rudder = c.MG_AXIS_RUDDER,
    wheel = c.MG_AXIS_WHEEL,
    gas = c.MG_AXIS_GAS,
    brake = c.MG_AXIS_BRAKE,
    _,

    /// Human-readable name, e.g. "X Axis".
    pub fn name(self: Axis) []const u8 {
        const ptr = c.mg_axis_get_name(@intFromEnum(self));
        if (ptr) |p| return std.mem.span(p);
        return "Unknown Axis";
    }

    pub fn toC(self: Axis) c.mg_axis {
        return @intFromEnum(self);
    }
};

/// Event type discriminant.
pub const EventType = enum(u8) {
    none = c.MG_EVENT_NONE,
    gamepad_connect = c.MG_EVENT_GAMEPAD_CONNECT,
    gamepad_disconnect = c.MG_EVENT_GAMEPAD_DISCONNECT,
    button_press = c.MG_EVENT_BUTTON_PRESS,
    button_release = c.MG_EVENT_BUTTON_RELEASE,
    axis_move = c.MG_EVENT_AXIS_MOVE,
};

/// A single event returned by `Gamepads.update()`.
pub const Event = struct {
    type: EventType,
    /// The gamepad involved. Always non-null for connect/disconnect/button/axis events.
    gamepad: ?Gamepad,
    /// Valid for `.button_press` and `.button_release`.
    button: Button,
    /// Valid for `.axis_move`.
    axis: Axis,
};

/// Owns the underlying C `mg_gamepads` state.
/// Allocate on the heap or as a field; do not copy.
pub const Gamepads = struct {
    /// Raw storage for the C mg_gamepads struct.
    /// Aligned to 16 bytes to satisfy any platform requirements.
    buf: []align(16) u8,
    allocator: std.mem.Allocator,

    /// Initialise the gamepad subsystem. Call once at startup.
    pub fn init(allocator: std.mem.Allocator) !Gamepads {
        const buf = try allocator.alignedAlloc(u8, 16, c.GAMEPADS_BUF_SIZE);
        @memset(buf, 0);
        c.mg_gamepads_init(buf.ptr);
        return .{ .buf = buf, .allocator = allocator };
    }

    /// Free all resources. Do not use the `Gamepads` value after this.
    pub fn deinit(self: *Gamepads) void {
        c.mg_gamepads_free(self.buf.ptr);
        self.allocator.free(self.buf);
    }

    pub fn update(self: *Gamepads) ?Event {
        var raw: c.mg_event = undefined;
        if (!c.mg_gamepads_update(self.buf.ptr, &raw)) return null;
        if (raw.type == c.MG_EVENT_NONE) return null;

        return Event{
            .type = @enumFromInt(raw.type),
            .gamepad = if (raw.gamepad) |gp| Gamepad{ .ptr = gp } else null,
            .button = @enumFromInt(raw.button),
            .axis = @enumFromInt(raw.axis),
        };
    }

    /// Load additional SDL-format gamepad mappings at runtime.
    /// `mapping_string` is a newline-separated list of mapping lines.
    /// Returns `true` on success.
    pub fn updateMappings(self: *Gamepads, mapping_string: [*:0]const u8) bool {
        return c.mg_update_gamepad_mappings(self.buf.ptr, mapping_string);
    }
};
