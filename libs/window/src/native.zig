const std = @import("std");

pub const RGFW_window = *anyopaque;
pub const RGFW_mouse = *anyopaque;
pub const RGFW_mouseButton = enum(u8) {
    left = 0,
    middle,
    right,
    misc1,
    misc2,
    misc3,
    misc4,
    misc5,
    final,
};
pub const RGFW_keymod = enum(u8) {
    caps_lock = 1 << 0,
    num_lock = 1 << 1,
    control = 1 << 2,
    alt = 1 << 3,
    shift = 1 << 4,
    super = 1 << 5,
    scroll_lock = 1 << 6,
};
pub const RGFW_eventType = enum(u8) {
    none = 0,
    key_pressed,
    key_released,
    char,
    mouse_button_pressed,
    mouse_button_released,
    mouse_scroll,
    mouse_pos_changed,
    window_moved,
    window_resized,
    focus_in,
    focus_out,
    mouse_enter,
    mouse_leave,
    window_refresh,
    quit,
    data_drop,
    data_drag,
    window_maximized,
    window_minimized,
    window_restored,
    scale_updated,
    monitor_connected,
    monitor_disconnected,
};

pub const RGFW_key = enum(u8) {
    null = 0,
    escape = 27,

    backtick = '`',

    @"0" = '0',
    @"1" = '1',
    @"2" = '2',
    @"3" = '3',
    @"4" = '4',
    @"5" = '5',
    @"6" = '6',
    @"7" = '7',
    @"8" = '8',
    @"9" = '9',

    minus = '-',
    equal = '=',

    backSpace = '\x08',
    tab = '\t',
    space = ' ',

    a = 'a',
    b = 'b',
    c = 'c',
    d = 'd',
    e = 'e',
    f = 'f',
    g = 'g',
    h = 'h',
    i = 'i',
    j = 'j',
    k = 'k',
    l = 'l',
    m = 'm',
    n = 'n',
    o = 'o',
    p = 'p',
    q = 'q',
    r = 'r',
    s = 's',
    t = 't',
    u = 'u',
    v = 'v',
    w = 'w',
    x = 'x',
    y = 'y',
    z = 'z',

    period = '.',
    comma = ',',
    slash = '/',

    bracket = '[',
    closeBracket = ']',
    semicolon = ';',
    apostrophe = '\'',
    backSlash = '\\',

    @"return" = '\n',

    delete = 127,

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
    F13,
    F14,
    F15,
    F16,
    F17,
    F18,
    F19,
    F20,
    F21,
    F22,
    F23,
    F24,
    F25,

    capsLock,
    shiftL,
    controlL,
    altL,
    superL,

    shiftR,
    controlR,
    altR,
    superR,

    up,
    down,
    left,
    right,

    insert,
    menu,
    end,
    home,
    pageUp,
    pageDown,

    numLock,

    kpSlash,
    kpMultiply,
    kpPlus,
    kpMinus,

    kpEqual,

    kp1,
    kp2,
    kp3,
    kp4,
    kp5,
    kp6,
    kp7,
    kp8,
    kp9,
    kp0,

    kpPeriod,
    kpReturn,

    scrollLock,
    printScreen,
    pause,

    world1,
    world2,

    keyLast = 255,
};

pub const RGFW_event = extern union {
    type: RGFW_eventType,
    common: RGFW_commonEvent,
    button: RGFW_mouseButtonEvent,
    scroll: RGFW_mouseScrollEvent,
    mouse: RGFW_mousePosEvent,
    key: RGFW_keyEvent,
    key_char: RGFW_keyCharEvent,
    drop: RGFW_dataDropEvent,
    drag: RGFW_dataDragEvent,
    scale: RGFW_scaleUpdatedEvent,
    monitor: RGFW_monitorEvent,
};

pub const RGFW_monitorEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    monitor: *anyopaque,
};

pub const RGFW_scaleUpdatedEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    x: f32,
    y: f32,
};

pub const RGFW_dataDragEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    x: i32,
    y: i32,
};
pub const RGFW_dataDropEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    files: [*c][*c]const u8,
    count: usize,
};
pub const RGFW_keyCharEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    value: u32,
};
pub const RGFW_keyEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    value: RGFW_key,
    repeat: bool,
    mod: RGFW_keymod,
};
pub const RGFW_mousePosEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    x: i32,
    y: i32,
    vecX: f32,
    vecY: f32,
};
pub const RGFW_mouseScrollEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    x: f32,
    y: f32,
};

pub const RGFW_commonEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
};

pub const RGFW_mouseButtonEvent = extern struct {
    type: RGFW_eventType,
    win: RGFW_window,
    value: RGFW_mouseButton,
};
pub const RGFW_format = enum(u8) {
    rgb8 = 0,
    bgr8,
    rgba8,
    argb8,
    bgra8,
    abgr8,
    count,
};
pub const RGFW_icon = enum(u8) {
    taskbar = 1 << 0,
    window = 1 << 1,
    both = (1 << 0) | (1 << 1),
};

pub const RGFW_mouseIcons = enum(u8) {
    normal = 0,
    arrow,
    ibeam,
    crosshair,
    pointing_hand,
    resize_ew,
    resize_ns,
    resize_nwse,
    resize_nesw,
    resize_nw,
    resize_n,
    resize_ne,
    resize_e,
    resize_se,
    resize_s,
    resize_sw,
    resize_w,
    resize_all,
    not_allowed,
    wait,
    progress,
    icon_count,
    icon_final = 16,
};

pub extern fn RGFW_createWindow(title: [*c]const u8, x: u32, y: u32, width: u32, height: u32, flags: u64) RGFW_window;
pub extern fn RGFW_window_shouldClose(window: RGFW_window) bool;
pub extern fn RGFW_window_setExitKey(window: RGFW_window, key: u8) void;
pub extern fn RGFW_window_checkEvent(window: RGFW_window, event: [*c]RGFW_event) bool;
pub extern fn RGFW_window_close(window: RGFW_window) void;
pub extern fn RGFW_window_center(window: RGFW_window) void;
pub extern fn RGFW_window_setShouldClose(window: RGFW_window, value: bool) void;
pub extern fn RGFW_window_getMouse(window: RGFW_window, x: [*c]i32, y: [*c]i32) void;
pub extern fn RGFW_window_setName(window: RGFW_window, title: [*c]const u8) void;
pub extern fn RGFW_window_resize(window: RGFW_window, width: i32, height: i32) void;
pub extern fn RGFW_window_setFullscreen(window: RGFW_window, fullscreen: bool) void;
pub extern fn RGFW_window_isMouseInside(window: RGFW_window) bool;
pub extern fn RGFW_window_isKeyPressed(window: RGFW_window, key: RGFW_key) bool;
pub extern fn RGFW_window_isKeyDown(window: RGFW_window, key: RGFW_key) bool;
pub extern fn RGFW_window_isKeyReleased(window: RGFW_window, key: RGFW_key) bool;
pub extern fn RGFW_window_isMousePressed(window: RGFW_window, button: RGFW_mouseButton) bool;
pub extern fn RGFW_window_isMouseDown(win: RGFW_window, button: RGFW_mouseButton) bool;
pub extern fn RGFW_window_isMouseReleased(win: RGFW_window, button: RGFW_mouseButton) bool;
pub extern fn RGFW_window_didMouseLeave(win: RGFW_window) bool;
pub extern fn RGFW_window_didMouseEnter(win: RGFW_window) bool;
pub extern fn RGFW_window_setIcon(win: RGFW_window, [*c]const u8, width: i32, height: i32, format: RGFW_format) void;
pub extern fn RGFW_window_setIconEx(win: RGFW_window, [*c]const u8, width: i32, height: i32, format: RGFW_format, icon: RGFW_icon) void;
pub extern fn RGFW_window_setMouseStandard(win: RGFW_window, mouse: RGFW_mouseIcons) void;
pub extern fn RGFW_window_setMouse(win: RGFW_window, RGFW_mouse) void;
pub extern fn RGFW_loadMouse(data: [*c]u8, width: i32, height: i32, format: RGFW_format) RGFW_mouse;
pub extern fn RGFW_freeMouse(mouse: RGFW_mouse) void;
// os specific
pub extern fn RGFW_window_getHWND(window: RGFW_window) *anyopaque;
pub extern fn RGFW_window_getWindow_OSX(window: RGFW_window) *anyopaque;
pub extern fn RGFW_window_getWindow_X11(window: RGFW_window) *anyopaque;
pub extern fn RGFW_window_getWindow_Wayland(window: RGFW_window) *anyopaque;

pub extern fn RGFW_pollEvents() void;
