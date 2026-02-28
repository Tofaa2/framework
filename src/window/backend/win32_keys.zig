const std = @import("std");
const input = @import("../input.zig");
const win32 = @import("win32").everything;

// ============================================================================
// Windows Virtual Key Code to Key mapping
// ============================================================================

pub fn win32VKToKey(vk: u16) input.Key {
    return switch (vk) {
        // Alphanumeric
        0x41 => .A,
        0x42 => .B,
        0x43 => .C,
        0x44 => .D,
        0x45 => .E,
        0x46 => .F,
        0x47 => .G,
        0x48 => .H,
        0x49 => .I,
        0x4A => .J,
        0x4B => .K,
        0x4C => .L,
        0x4D => .M,
        0x4E => .N,
        0x4F => .O,
        0x50 => .P,
        0x51 => .Q,
        0x52 => .R,
        0x53 => .S,
        0x54 => .T,
        0x55 => .U,
        0x56 => .V,
        0x57 => .W,
        0x58 => .X,
        0x59 => .Y,
        0x5A => .Z,

        // Numbers
        0x30 => .Num0,
        0x31 => .Num1,
        0x32 => .Num2,
        0x33 => .Num3,
        0x34 => .Num4,
        0x35 => .Num5,
        0x36 => .Num6,
        0x37 => .Num7,
        0x38 => .Num8,
        0x39 => .Num9,

        // Function keys
        @intFromEnum(win32.VK_F1) => .F1,
        @intFromEnum(win32.VK_F2) => .F2,
        @intFromEnum(win32.VK_F3) => .F3,
        @intFromEnum(win32.VK_F4) => .F4,
        @intFromEnum(win32.VK_F5) => .F5,
        @intFromEnum(win32.VK_F6) => .F6,
        @intFromEnum(win32.VK_F7) => .F7,
        @intFromEnum(win32.VK_F8) => .F8,
        @intFromEnum(win32.VK_F9) => .F9,
        @intFromEnum(win32.VK_F10) => .F10,
        @intFromEnum(win32.VK_F11) => .F11,
        @intFromEnum(win32.VK_F12) => .F12,

        // Special keys
        @intFromEnum(win32.VK_ESCAPE) => .Escape,
        @intFromEnum(win32.VK_TAB) => .Tab,
        @intFromEnum(win32.VK_CAPITAL) => .CapsLock,
        @intFromEnum(win32.VK_LSHIFT) => .LeftShift,
        @intFromEnum(win32.VK_RSHIFT) => .RightShift,
        @intFromEnum(win32.VK_LCONTROL) => .LeftControl,
        @intFromEnum(win32.VK_RCONTROL) => .RightControl,
        @intFromEnum(win32.VK_LMENU) => .LeftAlt,
        @intFromEnum(win32.VK_RMENU) => .RightAlt,
        @intFromEnum(win32.VK_LWIN) => .LeftSuper,
        @intFromEnum(win32.VK_RWIN) => .RightSuper,
        @intFromEnum(win32.VK_SPACE) => .Space,
        @intFromEnum(win32.VK_RETURN) => .Enter,
        @intFromEnum(win32.VK_BACK) => .Backspace,
        @intFromEnum(win32.VK_DELETE) => .Delete,
        @intFromEnum(win32.VK_INSERT) => .Insert,
        @intFromEnum(win32.VK_HOME) => .Home,
        @intFromEnum(win32.VK_END) => .End,
        @intFromEnum(win32.VK_PRIOR) => .PageUp,
        @intFromEnum(win32.VK_NEXT) => .PageDown,

        // Arrow keys
        @intFromEnum(win32.VK_LEFT) => .Left,
        @intFromEnum(win32.VK_RIGHT) => .Right,
        @intFromEnum(win32.VK_UP) => .Up,
        @intFromEnum(win32.VK_DOWN) => .Down,

        // Punctuation
        @intFromEnum(win32.VK_OEM_MINUS) => .Minus, // -_
        @intFromEnum(win32.VK_OEM_PLUS) => .Equals, // =+
        @intFromEnum(win32.VK_OEM_4) => .LeftBracket, // [{
        @intFromEnum(win32.VK_OEM_6) => .RightBracket, // ]}
        @intFromEnum(win32.VK_OEM_5) => .Backslash, // \|
        @intFromEnum(win32.VK_OEM_1) => .Semicolon, // ;:
        @intFromEnum(win32.VK_OEM_7) => .Apostrophe, // '"
        @intFromEnum(win32.VK_OEM_COMMA) => .Comma, // ,<
        @intFromEnum(win32.VK_OEM_PERIOD) => .Period, // .>
        @intFromEnum(win32.VK_OEM_2) => .Slash, // /?
        @intFromEnum(win32.VK_OEM_3) => .Grave, // `~

        // Numpad
        @intFromEnum(win32.VK_NUMPAD0) => .Numpad0,
        @intFromEnum(win32.VK_NUMPAD1) => .Numpad1,
        @intFromEnum(win32.VK_NUMPAD2) => .Numpad2,
        @intFromEnum(win32.VK_NUMPAD3) => .Numpad3,
        @intFromEnum(win32.VK_NUMPAD4) => .Numpad4,
        @intFromEnum(win32.VK_NUMPAD5) => .Numpad5,
        @intFromEnum(win32.VK_NUMPAD6) => .Numpad6,
        @intFromEnum(win32.VK_NUMPAD7) => .Numpad7,
        @intFromEnum(win32.VK_NUMPAD8) => .Numpad8,
        @intFromEnum(win32.VK_NUMPAD9) => .Numpad9,
        @intFromEnum(win32.VK_MULTIPLY) => .NumpadMultiply,
        @intFromEnum(win32.VK_ADD) => .NumpadAdd,
        @intFromEnum(win32.VK_SUBTRACT) => .NumpadSubtract,
        @intFromEnum(win32.VK_DECIMAL) => .NumpadDecimal,
        @intFromEnum(win32.VK_DIVIDE) => .NumpadDivide,
        @intFromEnum(win32.VK_NUMLOCK) => .NumLock,

        // Misc
        @intFromEnum(win32.VK_SNAPSHOT) => .PrintScreen,
        @intFromEnum(win32.VK_SCROLL) => .ScrollLock,
        @intFromEnum(win32.VK_PAUSE) => .Pause,
        @intFromEnum(win32.VK_APPS) => .Menu,

        else => .Unknown,
    };
}

pub fn keyToWin32VK(key: input.Key) u16 {
    return switch (key) {
        // Alphanumeric
        .A => 0x41,
        .B => 0x42,
        .C => 0x43,
        .D => 0x44,
        .E => 0x45,
        .F => 0x46,
        .G => 0x47,
        .H => 0x48,
        .I => 0x49,
        .J => 0x4A,
        .K => 0x4B,
        .L => 0x4C,
        .M => 0x4D,
        .N => 0x4E,
        .O => 0x4F,
        .P => 0x50,
        .Q => 0x51,
        .R => 0x52,
        .S => 0x53,
        .T => 0x54,
        .U => 0x55,
        .V => 0x56,
        .W => 0x57,
        .X => 0x58,
        .Y => 0x59,
        .Z => 0x5A,

        // Numbers
        .Num0 => 0x30,
        .Num1 => 0x31,
        .Num2 => 0x32,
        .Num3 => 0x33,
        .Num4 => 0x34,
        .Num5 => 0x35,
        .Num6 => 0x36,
        .Num7 => 0x37,
        .Num8 => 0x38,
        .Num9 => 0x39,

        // Function keys
        .F1 => @intFromEnum(win32.VK_F1),
        .F2 => @intFromEnum(win32.VK_F2),
        .F3 => @intFromEnum(win32.VK_F3),
        .F4 => @intFromEnum(win32.VK_F4),
        .F5 => @intFromEnum(win32.VK_F5),
        .F6 => @intFromEnum(win32.VK_F6),
        .F7 => @intFromEnum(win32.VK_F7),
        .F8 => @intFromEnum(win32.VK_F8),
        .F9 => @intFromEnum(win32.VK_F9),
        .F10 => @intFromEnum(win32.VK_F10),
        .F11 => @intFromEnum(win32.VK_F11),
        .F12 => @intFromEnum(win32.VK_F12),

        // Special keys
        .Escape => @intFromEnum(win32.VK_ESCAPE),
        .Tab => @intFromEnum(win32.VK_TAB),
        .CapsLock => @intFromEnum(win32.VK_CAPITAL),
        .LeftShift => @intFromEnum(win32.VK_LSHIFT),
        .RightShift => @intFromEnum(win32.VK_RSHIFT),
        .LeftControl => @intFromEnum(win32.VK_LCONTROL),
        .RightControl => @intFromEnum(win32.VK_RCONTROL),
        .LeftAlt => @intFromEnum(win32.VK_LMENU),
        .RightAlt => @intFromEnum(win32.VK_RMENU),
        .LeftSuper => @intFromEnum(win32.VK_LWIN),
        .RightSuper => @intFromEnum(win32.VK_RWIN),
        .Space => @intFromEnum(win32.VK_SPACE),
        .Enter => @intFromEnum(win32.VK_RETURN),
        .Backspace => @intFromEnum(win32.VK_BACK),
        .Delete => @intFromEnum(win32.VK_DELETE),
        .Insert => @intFromEnum(win32.VK_INSERT),
        .Home => @intFromEnum(win32.VK_HOME),
        .End => @intFromEnum(win32.VK_END),
        .PageUp => @intFromEnum(win32.VK_PRIOR),
        .PageDown => @intFromEnum(win32.VK_NEXT),

        // Arrow keys
        .Left => @intFromEnum(win32.VK_LEFT),
        .Right => @intFromEnum(win32.VK_RIGHT),
        .Up => @intFromEnum(win32.VK_UP),
        .Down => @intFromEnum(win32.VK_DOWN),

        // Punctuation
        .Minus => @intFromEnum(win32.VK_OEM_MINUS),
        .Equals => @intFromEnum(win32.VK_OEM_PLUS),
        .LeftBracket => @intFromEnum(win32.VK_OEM_4),
        .RightBracket => @intFromEnum(win32.VK_OEM_6),
        .Backslash => @intFromEnum(win32.VK_OEM_5),
        .Semicolon => @intFromEnum(win32.VK_OEM_1),
        .Apostrophe => @intFromEnum(win32.VK_OEM_7),
        .Comma => @intFromEnum(win32.VK_OEM_COMMA),
        .Period => @intFromEnum(win32.VK_OEM_PERIOD),
        .Slash => @intFromEnum(win32.VK_OEM_2),
        .Grave => @intFromEnum(win32.VK_OEM_3),

        // Numpad
        .Numpad0 => @intFromEnum(win32.VK_NUMPAD0),
        .Numpad1 => @intFromEnum(win32.VK_NUMPAD1),
        .Numpad2 => @intFromEnum(win32.VK_NUMPAD2),
        .Numpad3 => @intFromEnum(win32.VK_NUMPAD3),
        .Numpad4 => @intFromEnum(win32.VK_NUMPAD4),
        .Numpad5 => @intFromEnum(win32.VK_NUMPAD5),
        .Numpad6 => @intFromEnum(win32.VK_NUMPAD6),
        .Numpad7 => @intFromEnum(win32.VK_NUMPAD7),
        .Numpad8 => @intFromEnum(win32.VK_NUMPAD8),
        .Numpad9 => @intFromEnum(win32.VK_NUMPAD9),
        .NumpadMultiply => @intFromEnum(win32.VK_MULTIPLY),
        .NumpadAdd => @intFromEnum(win32.VK_ADD),
        .NumpadSubtract => @intFromEnum(win32.VK_SUBTRACT),
        .NumpadDecimal => @intFromEnum(win32.VK_DECIMAL),
        .NumpadDivide => @intFromEnum(win32.VK_DIVIDE),
        .NumpadEnter => @intFromEnum(win32.VK_RETURN),
        .NumLock => @intFromEnum(win32.VK_NUMLOCK),

        // Misc
        .PrintScreen => @intFromEnum(win32.VK_SNAPSHOT),
        .ScrollLock => @intFromEnum(win32.VK_SCROLL),
        .Pause => @intFromEnum(win32.VK_PAUSE),
        .Menu => @intFromEnum(win32.VK_APPS),

        .Unknown => 0,
    };
}

// ============================================================================
// Helper functions
// ============================================================================

pub fn isKeyDown(vk: u16) bool {
    return (win32.GetAsyncKeyState(@intCast(vk)) & 0x8000) != 0;
}

pub fn wasKeyPressed(vk: u16) bool {
    return (win32.GetAsyncKeyState(@intCast(vk)) & 0x0001) != 0;
}

pub fn getModifierState() input.Modifiers {
    return .{
        .shift = isKeyDown(@intFromEnum(win32.VK_SHIFT)),
        .ctrl = isKeyDown(@intFromEnum(win32.VK_CONTROL)),
        .alt = isKeyDown(@intFromEnum(win32.VK_MENU)),
        .super = isKeyDown(@intFromEnum(win32.VK_LWIN)) or isKeyDown(@intFromEnum(win32.VK_RWIN)),
        .caps_lock = (win32.GetKeyState(@intFromEnum(win32.VK_CAPITAL)) & 0x0001) != 0,
        .num_lock = (win32.GetKeyState(@intFromEnum(win32.VK_NUMLOCK)) & 0x0001) != 0,
    };
}

// ============================================================================
// Extended key detection (for Left/Right modifier differentiation)
// ============================================================================

pub fn getExtendedKeyCode(vk: u16, flags: u32) u16 {
    const extended = (flags & 0x01000000) != 0; // KF_EXTENDED flag

    return switch (vk) {
        @intFromEnum(win32.VK_SHIFT) => if (extended) @intFromEnum(win32.VK_RSHIFT) else @intFromEnum(win32.VK_LSHIFT),
        @intFromEnum(win32.VK_CONTROL) => if (extended) @intFromEnum(win32.VK_RCONTROL) else @intFromEnum(win32.VK_LCONTROL),
        @intFromEnum(win32.VK_MENU) => if (extended) @intFromEnum(win32.VK_RMENU) else @intFromEnum(win32.VK_LMENU),
        @intFromEnum(win32.VK_RETURN) => if (extended) @intFromEnum(win32.VK_RETURN) else @intFromEnum(win32.VK_RETURN), // Numpad Enter
        else => vk,
    };
}
