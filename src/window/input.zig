const std = @import("std");

// ============================================================================
// Key Codes - Cross-platform key definitions
// ============================================================================

pub const Key = enum(u16) {
    // Alphanumeric
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,

    // Numbers
    Num0,
    Num1,
    Num2,
    Num3,
    Num4,
    Num5,
    Num6,
    Num7,
    Num8,
    Num9,

    // Function keys
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,

    // Special keys
    Escape,
    Tab,
    CapsLock,
    LeftShift,
    RightShift,
    LeftControl,
    RightControl,
    LeftAlt,
    RightAlt,
    LeftSuper, // Windows key / Command key
    RightSuper,
    Space,
    Enter,
    Backspace,
    Delete,
    Insert,
    Home,
    End,
    PageUp,
    PageDown,

    // Arrow keys
    Left,
    Right,
    Up,
    Down,

    // Punctuation
    Minus,
    Equals,
    LeftBracket,
    RightBracket,
    Backslash,
    Semicolon,
    Apostrophe,
    Comma,
    Period,
    Slash,
    Grave,

    // Numpad
    Numpad0,
    Numpad1,
    Numpad2,
    Numpad3,
    Numpad4,
    Numpad5,
    Numpad6,
    Numpad7,
    Numpad8,
    Numpad9,
    NumpadMultiply,
    NumpadAdd,
    NumpadSubtract,
    NumpadDecimal,
    NumpadDivide,
    NumpadEnter,
    NumLock,

    // Misc
    PrintScreen,
    ScrollLock,
    Pause,
    Menu,

    Unknown,
};

pub const MouseButton = enum(u8) {
    Left,
    Right,
    Middle,
    X1,
    X2,
};

pub const KeyState = enum(u8) {
    Released,
    Pressed,
    Repeat,
};

pub const MouseState = enum(u8) {
    Released,
    Pressed,
};

// ============================================================================
// Input Events
// ============================================================================

pub const KeyEvent = struct {
    key: Key,
    state: KeyState,
    modifiers: Modifiers,
};

pub const MouseButtonEvent = struct {
    button: MouseButton,
    state: MouseState,
    x: i32,
    y: i32,
    modifiers: Modifiers,
};

pub const MouseMoveEvent = struct {
    x: i32,
    y: i32,
    delta_x: i32,
    delta_y: i32,
};

pub const MouseScrollEvent = struct {
    delta_x: f32,
    delta_y: f32,
    x: i32,
    y: i32,
};

pub const Modifiers = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
};

// ============================================================================
// Input State Manager
// ============================================================================

// Maximum number of events per frame
pub const MAX_KEY_EVENTS = 256;
pub const MAX_MOUSE_BUTTON_EVENTS = 32;
pub const MAX_MOUSE_MOVE_EVENTS = 128;
pub const MAX_MOUSE_SCROLL_EVENTS = 32;

pub const InputState = struct {
    allocator: std.mem.Allocator,

    // Keyboard state
    key_states: [256]KeyState,
    modifiers: Modifiers,

    // Mouse state
    mouse_button_states: [5]MouseState,
    mouse_x: i32,
    mouse_y: i32,
    last_mouse_x: i32,
    last_mouse_y: i32,
    scroll_delta_x: f32,
    scroll_delta_y: f32,

    // Event queues (fixed-size arrays with counts)
    key_events: [MAX_KEY_EVENTS]KeyEvent,
    key_event_count: usize,

    mouse_button_events: [MAX_MOUSE_BUTTON_EVENTS]MouseButtonEvent,
    mouse_button_event_count: usize,

    mouse_move_events: [MAX_MOUSE_MOVE_EVENTS]MouseMoveEvent,
    mouse_move_event_count: usize,

    mouse_scroll_events: [MAX_MOUSE_SCROLL_EVENTS]MouseScrollEvent,
    mouse_scroll_event_count: usize,

    pub fn init(allocator: std.mem.Allocator) !*InputState {
        const self = try allocator.create(InputState);

        self.* = .{
            .allocator = allocator,
            .key_states = [_]KeyState{.Released} ** 256,
            .modifiers = .{},
            .mouse_button_states = [_]MouseState{.Released} ** 5,
            .mouse_x = 0,
            .mouse_y = 0,
            .last_mouse_x = 0,
            .last_mouse_y = 0,
            .scroll_delta_x = 0,
            .scroll_delta_y = 0,
            .key_events = undefined,
            .key_event_count = 0,
            .mouse_button_events = undefined,
            .mouse_button_event_count = 0,
            .mouse_move_events = undefined,
            .mouse_move_event_count = 0,
            .mouse_scroll_events = undefined,
            .mouse_scroll_event_count = 0,
        };

        return self;
    }

    pub fn deinit(self: *InputState) void {
        self.allocator.destroy(self);
    }

    // ========================================================================
    // Frame Management
    // ========================================================================

    pub fn beginFrame(self: *InputState) void {
        // Reset event counts
        self.key_event_count = 0;
        self.mouse_button_event_count = 0;
        self.mouse_move_event_count = 0;
        self.mouse_scroll_event_count = 0;

        // Reset scroll deltas
        self.scroll_delta_x = 0;
        self.scroll_delta_y = 0;

        // Update last mouse position
        self.last_mouse_x = self.mouse_x;
        self.last_mouse_y = self.mouse_y;
    }

    // ========================================================================
    // Key State Queries
    // ========================================================================

    pub fn isKeyPressed(self: *InputState, key: Key) bool {
        const index = @intFromEnum(key);
        if (index >= self.key_states.len) return false;

        const state = self.key_states[index];
        return state == .Pressed or state == .Repeat;
    }

    pub fn isKeyJustPressed(self: *InputState, key: Key) bool {
        const events = self.key_events[0..self.key_event_count];
        for (events) |event| {
            if (event.key == key and event.state == .Pressed) {
                return true;
            }
        }
        return false;
    }

    pub fn isKeyJustReleased(self: *InputState, key: Key) bool {
        const events = self.key_events[0..self.key_event_count];
        for (events) |event| {
            if (event.key == key and event.state == .Released) {
                return true;
            }
        }
        return false;
    }

    // ========================================================================
    // Mouse State Queries
    // ========================================================================

    pub fn isMouseButtonPressed(self: *InputState, button: MouseButton) bool {
        const index = @intFromEnum(button);
        if (index >= self.mouse_button_states.len) return false;

        const state = self.mouse_button_states[index];
        return state == .Pressed;
    }

    pub fn isMouseButtonJustPressed(self: *InputState, button: MouseButton) bool {
        const events = self.mouse_button_events[0..self.mouse_button_event_count];
        for (events) |event| {
            if (event.button == button and event.state == .Pressed) {
                return true;
            }
        }
        return false;
    }

    pub fn isMouseButtonJustReleased(self: *InputState, button: MouseButton) bool {
        const events = self.mouse_button_events[0..self.mouse_button_event_count];
        for (events) |event| {
            if (event.button == button and event.state == .Released) {
                return true;
            }
        }
        return false;
    }

    pub fn getMousePosition(self: *InputState) struct { x: i32, y: i32 } {
        return .{ .x = self.mouse_x, .y = self.mouse_y };
    }

    pub fn getMouseDelta(self: *InputState) struct { x: i32, y: i32 } {
        return .{
            .x = self.mouse_x - self.last_mouse_x,
            .y = self.mouse_y - self.last_mouse_y,
        };
    }

    pub fn getScrollDelta(self: *InputState) struct { x: f32, y: f32 } {
        return .{ .x = self.scroll_delta_x, .y = self.scroll_delta_y };
    }

    // ========================================================================
    // Event Array Accessors
    // ========================================================================

    pub fn getKeyEvents(self: *InputState) []const KeyEvent {
        return self.key_events[0..self.key_event_count];
    }

    pub fn getMouseButtonEvents(self: *InputState) []const MouseButtonEvent {
        return self.mouse_button_events[0..self.mouse_button_event_count];
    }

    pub fn getMouseMoveEvents(self: *InputState) []const MouseMoveEvent {
        return self.mouse_move_events[0..self.mouse_move_event_count];
    }

    pub fn getMouseScrollEvents(self: *InputState) []const MouseScrollEvent {
        return self.mouse_scroll_events[0..self.mouse_scroll_event_count];
    }

    // ========================================================================
    // Internal Event Handling
    // ========================================================================

    pub fn handleKeyEvent(self: *InputState, key: Key, state: KeyState) !void {
        // Update key state in array
        const index = @intFromEnum(key);
        if (index < self.key_states.len) {
            self.key_states[index] = state;
        }

        // Update modifiers
        self.updateModifiers(key, state);

        // Add to event queue if space available
        if (self.key_event_count < MAX_KEY_EVENTS) {
            self.key_events[self.key_event_count] = .{
                .key = key,
                .state = state,
                .modifiers = self.modifiers,
            };
            self.key_event_count += 1;
        }
    }

    pub fn handleMouseButtonEvent(self: *InputState, button: MouseButton, state: MouseState) !void {
        // Update button state in array
        const index = @intFromEnum(button);
        if (index < self.mouse_button_states.len) {
            self.mouse_button_states[index] = state;
        }

        // Add to event queue if space available
        if (self.mouse_button_event_count < MAX_MOUSE_BUTTON_EVENTS) {
            self.mouse_button_events[self.mouse_button_event_count] = .{
                .button = button,
                .state = state,
                .x = self.mouse_x,
                .y = self.mouse_y,
                .modifiers = self.modifiers,
            };
            self.mouse_button_event_count += 1;
        }
    }

    pub fn handleMouseMove(self: *InputState, x: i32, y: i32) !void {
        const delta_x = x - self.mouse_x;
        const delta_y = y - self.mouse_y;

        self.mouse_x = x;
        self.mouse_y = y;

        if ((delta_x != 0 or delta_y != 0) and self.mouse_move_event_count < MAX_MOUSE_MOVE_EVENTS) {
            self.mouse_move_events[self.mouse_move_event_count] = .{
                .x = x,
                .y = y,
                .delta_x = delta_x,
                .delta_y = delta_y,
            };
            self.mouse_move_event_count += 1;
        }
    }

    pub fn handleMouseScroll(self: *InputState, delta_x: f32, delta_y: f32) !void {
        self.scroll_delta_x += delta_x;
        self.scroll_delta_y += delta_y;

        if (self.mouse_scroll_event_count < MAX_MOUSE_SCROLL_EVENTS) {
            self.mouse_scroll_events[self.mouse_scroll_event_count] = .{
                .delta_x = delta_x,
                .delta_y = delta_y,
                .x = self.mouse_x,
                .y = self.mouse_y,
            };
            self.mouse_scroll_event_count += 1;
        }
    }

    fn updateModifiers(self: *InputState, key: Key, state: KeyState) void {
        const pressed = (state == .Pressed or state == .Repeat);

        switch (key) {
            .LeftShift, .RightShift => self.modifiers.shift = pressed,
            .LeftControl, .RightControl => self.modifiers.ctrl = pressed,
            .LeftAlt, .RightAlt => self.modifiers.alt = pressed,
            .LeftSuper, .RightSuper => self.modifiers.super = pressed,
            .CapsLock => {
                if (state == .Pressed) {
                    self.modifiers.caps_lock = !self.modifiers.caps_lock;
                }
            },
            .NumLock => {
                if (state == .Pressed) {
                    self.modifiers.num_lock = !self.modifiers.num_lock;
                }
            },
            else => {},
        }
    }
};
