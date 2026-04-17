pub const WindowFlags = enum(u32) {
    no_border = 1 << 0,
    no_resize = 1 << 1,
    allow_dnd = 1 << 2,
    hide_mouse = 1 << 3,
    fullscreen = 1 << 4,
    transparent = 1 << 5,
    center = 1 << 6,
    raw_mouse = 1 << 7,
    scale_to_monitor = 1 << 8,
    hide = 1 << 9,
    maximize = 1 << 10,
    center_cursor = 1 << 11,
    floating = 1 << 12,
    focus_on_show = 1 << 13,
    minimize = 1 << 14,
    focus = 1 << 15,
    capture_mouse = 1 << 16,
    opengl = 1 << 17,
    egl = 1 << 18,
    no_deinit_on_close = 1 << 19,
    windowed_fullscreen = (1 << 0) | (1 << 10),
    capture_raw_mouse = (1 << 16) | (1 << 7),
};

pub const MousePos = struct {
    x: i32,
    y: i32,
};

pub const Format = enum(u8) {
    rgb8 = 0,
    bgr8,
    rgba8,
    argb8,
    bgra8,
    abgr8,
    count,
};
pub const Icon = enum(u8) {
    taskbar = 1 << 0,
    window = 1 << 1,
    both = (1 << 0) | (1 << 1),
};

pub const MouseIcons = enum(u8) {
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

pub const Key = enum(u8) {
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

pub const MouseButton = enum(u8) {
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

pub const Keymod = packed struct(u8) {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,
    __unused: u1 = 0,

    pub fn has(self: Keymod, mod: Keymod) bool {
        return @as(u8, @bitCast(self)) & @as(u8, @bitCast(mod)) != 0;
    }
};
