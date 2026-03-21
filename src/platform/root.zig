const std = @import("std");
const builtin = @import("builtin");

pub const c = @import("thirdparty").rgfw;

const KEY_COUNT = 256;

pub const Window = struct {
    handle: ?*c.RGFW_window,
    width: u32,
    height: u32,
    data: []usize, // TODO: Probably ArrayList is better
    mouse_delta: [2]f32 = .{ 0.0, 0.0 },
    resized_last_frame: bool = false,
    keys_pressed: [KEY_COUNT]bool = [_]bool{false} ** KEY_COUNT,
    keys_down: [KEY_COUNT]bool = [_]bool{false} ** KEY_COUNT,
    keys_released: [KEY_COUNT]bool = [_]bool{false} ** KEY_COUNT,

    pub fn getFrameBufferSize(self: *Window) [2]i32 {
        var width: i32 = undefined;
        var height: i32 = undefined;
        _ = c.RGFW_window_getSize(self.handle, &width, &height);
        return .{ width, height };
    }
    pub fn isKeyPressed(self: *Window, key: RGFW_key) bool {
        const k: usize = @intFromEnum(key);
        if (k >= KEY_COUNT) return false;
        return self.keys_pressed[k];
    }

    pub fn isKeyDown(self: *Window, key: RGFW_key) bool {
        const k: usize = @intFromEnum(key);
        if (k >= KEY_COUNT) return false;
        return self.keys_down[k];
    }

    pub fn isKeyReleased(self: *Window, key: RGFW_key) bool {
        const k: usize = @intFromEnum(key);
        if (k >= KEY_COUNT) return false;
        return self.keys_released[k];
    }

    //
    // pub fn isKeyReleased(self: *Window, key: RGFW_key) bool {
    //     return c.RGFW_window_isKeyReleased(self.handle, @intFromEnum(key)) == 1;
    // }
    //
    // pub fn isKeyDown(self: *Window, key: RGFW_key) bool {
    //     return c.RGFW_window_isKeyDown(self.handle, @intFromEnum(key)) == 1;
    // }
    //
    // pub fn isKeyPressed(self: *Window, key: RGFW_key) bool {
    //     const res = c.RGFW_window_isKeyPressed(self.handle, @intFromEnum(key));
    //     return res == 1;
    // }

    pub fn getWindowFromNative(handle: ?*c.RGFW_window) ?*Window {
        const native = c.RGFW_window_getUserPtr(handle);
        return @as(?*Window, @ptrCast(@alignCast(native)));
    }

    pub fn isMouseInside(self: *Window) bool {
        return c.RGFW_window_isMouseInside(self.handle) == 1;
    }

    pub fn didMouseEnter(self: *Window) bool {
        return c.RGFW_window_didMouseEnter(self.handle) == 1;
    }

    pub fn didMouseLeave(self: *Window) bool {
        return c.RGFW_window_didMouseLeave(self.handle) == 1;
    }

    pub fn isMousePressed(self: *Window, button: RGFW_mouseButton) bool {
        return c.RGFW_window_isMousePressed(self.handle, @intFromEnum(button)) == 1;
    }

    pub fn isMouseDown(self: *Window, button: RGFW_mouseButton) bool {
        return c.RGFW_window_isMouseDown(self.handle, @intFromEnum(button)) == 1;
    }

    pub fn isMouseReleased(self: *Window, button: RGFW_mouseButton) bool {
        return c.RGFW_window_isMouseReleased(self.handle, @intFromEnum(button)) == 1;
    }

    pub fn setFullscreen(self: *Window, fullscreen: bool) void {
        c.RGFW_window_setFullscreen(self.handle, @intFromBool(fullscreen));
    }

    pub fn setName(self: *Window, title: []const u8) void {
        c.RGFW_window_setName(self.handle, @ptrCast(title.ptr));
    }

    pub fn resize(self: *Window, nw: u32, nh: u32) void {
        c.RGFW_window_resize(self.handle, @intCast(nw), @intCast(nh));
    }

    pub fn getNativePtr(self: *Window) ?*anyopaque {
        return switch (builtin.os.tag) {
            .windows => c.RGFW_window_getHWND(self.handle),
            .macos => c.RGFW_window_getWindow_OSX(self.handle),
            .linux => {
                const env = std.posix.getenv;
                var ptr: ?*anyopaque = null;
                if (env("DISPLAY") != null or env("XDG_SESSION_TYPE") != null) {
                    ptr = @ptrFromInt(c.RGFW_window_getWindow_X11(self.handle));
                } else if (env("WAYLAND_DISPLAY")) |_| {
                    ptr = (c.RGFW_window_getWindow_Wayland(self.handle));
                } else {
                    @panic("Idk what your linux window manager is bruh");
                }
                return ptr;
            },
            else => @panic("Your OS is not supported for the custom Window struct"),
        };
    }

    pub fn getNativeNdt(self: *Window) ?*anyopaque {
        return switch (builtin.os.tag) {
            .windows => c.RGFW_window_getHDC(self.handle),
            .linux => {
                const env = std.posix.getenv;
                var ptr: ?*anyopaque = null;
                if (env("DISPLAY") != null or env("XDG_SESSION_TYPE") != null) {
                    ptr = c.RGFW_getDisplay_X11();
                } else if (env("WAYLAND_DISPLAY") != null) {
                    ptr = c.RGFW_getDisplay_Wayland();
                } else {
                    @panic("Idk what your linux window manager is bruh");
                }
                return ptr;
            },
            else => {
                return null;
            }
        };
    }

    pub fn setIcon(self: *Window, data: [*c]const u8, width: u32, height: u32, format: RGFW_format) void {
        _ = c.RGFW_window_setIcon(self.handle, data, width, height, format);
    }

    pub fn getMouse(self: *Window) MousePos {
        var x: i32 = undefined;
        var y: i32 = undefined;
        _ = c.RGFW_window_getMouse(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    pub fn update(self: *Window) void {
        const old_width = self.width;
        const old_height = self.height;
        self.mouse_delta = .{ 0.0, 0.0 };
        // reset per-frame states
        @memset(&self.keys_pressed, false);
        @memset(&self.keys_released, false);

        var event: c.RGFW_event = undefined;
        while (c.RGFW_window_checkEvent(self.handle, &event) == 1) {
            if (event.type == 17) {
                c.RGFW_window_setShouldClose(self.handle, @intFromBool(true));
                break;
            }
            if (event.type == c.RGFW_mousePosChanged) {
                self.mouse_delta[0] += event.mouse.vecX;
                self.mouse_delta[1] += event.mouse.vecY;
            }
            if (event.type == c.RGFW_keyPressed) {
                const key: usize = @intCast(event.key.value);
                if (key < KEY_COUNT) {
                    self.keys_pressed[key] = true;
                    self.keys_down[key] = true;
                }
            }
            if (event.type == c.RGFW_keyReleased) {
                const key: usize = @intCast(event.key.value);
                if (key < KEY_COUNT) {
                    self.keys_released[key] = true;
                    self.keys_down[key] = false;
                }
            }
        }

        var new_w: i32 = undefined;
        var new_h: i32 = undefined;
        _ = c.RGFW_window_getSize(self.handle, &new_w, &new_h);
        self.width = @intCast(new_w);
        self.height = @intCast(new_h);

        if (old_width != self.width or old_height != self.height) {
            self.resized_last_frame = true;
        } else {
            self.resized_last_frame = false;
        }
    }

    // fn update0(self: *Window) void {
    //     const old_width = self.width;
    //     const old_height = self.height;
    //     self.mouse_delta = .{ 0.0, 0.0 };
    //
    //     var event: c.RGFW_event = undefined;
    //     while (c.RGFW_window_checkEvent(self.handle, &event) == 1) {
    //         if (event.type == 17) {
    //             c.RGFW_window_setShouldClose(self.handle, @intFromBool(true));
    //             break;
    //         }
    //         if (event.type == c.RGFW_mousePosChanged) {
    //             self.mouse_delta[0] += event.mouse.vecX;
    //             self.mouse_delta[1] += event.mouse.vecY;
    //         }
    //     }
    //
    //     var new_w: i32 = undefined;
    //     var new_h: i32 = undefined;
    //     _ = c.RGFW_window_getSize(self.handle, &new_w, &new_h);
    //     self.width = @intCast(new_w);
    //     self.height = @intCast(new_h);
    //
    //     if (old_width != self.width or old_height != self.height) {
    //         self.resized_last_frame = true;
    //     } else {
    //         self.resized_last_frame = false;
    //     }
    // }
    pub fn getMouseDelta(self: *Window) [2]f32 {
        return self.mouse_delta;
    }
    pub fn setFlagsRaw(self: *Window, flags: u32) void {
        c.RGFW_window_setFlags(self.handle, flags);
    }

    pub fn setFlags(self: *Window, flags: []const RGFW_windowFlags) void {
        var result: u32 = 0;
        for (flags) |flag| {
            result |= @intFromEnum(flag);
        }
        c.RGFW_window_setFlags(self.handle, result);
    }

    pub fn getFlags(self: *Window) u32 {
        return c.RGFW_window_getFlags(self.handle);
    }

    pub fn shouldClose(self: *Window) bool {
        return c.RGFW_window_shouldClose(self.handle) == c.RGFW_TRUE;
    }

    pub fn setupCallbacks(self: *Window) void {
        c.RGFW_window_setUserPtr(self.handle, self);
        _ = c.RGFW_setWindowResizedCallback(struct {
            fn func(window: ?*c.RGFW_window, width: i32, height: i32) callconv(.c) void {
                const our_window = Window.getWindowFromNative(window) orelse {
                    std.log.err("Failed to cast window pointer to *Window", .{});
                    return;
                };
                our_window.height = @intCast(height);
                our_window.width = @intCast(width);
                for (our_window.callbacks.resize.items) |callback| {
                    callback(our_window, @intCast(width), @intCast(height));
                }
            }
        }.func);
    }

    pub fn getData(self: *Window, index: usize, comptime T: type) ?*T {
        if (index >= self.data.len) return null;
        return @ptrFromInt(self.data[index]);
    }

    pub fn setData(self: *Window, index: usize, value: *anyopaque) void {
        if (index >= self.data.len) return;
        self.data[index] = @intFromPtr(value);
    }
    pub fn setMouseCaptured(self: *Window, captured: bool) void {
        const current = self.getFlags();
        const flags = @intFromEnum(RGFW_windowFlags.capture_mouse) |
            @intFromEnum(RGFW_windowFlags.hide_mouse) |
            @intFromEnum(RGFW_windowFlags.raw_mouse);
        if (captured) {
            c.RGFW_window_setFlags(self.handle, current | flags);
        } else {
            c.RGFW_window_setFlags(self.handle, current & ~flags);
        }
    }
    pub fn init(title: []const u8, width: u32, height: u32) Window {
        const handle = c.RGFW_createWindow(@ptrCast(title.ptr), 0, 0, @intCast(width), @intCast(height), 0);

        c.RGFW_window_center(handle);

        return .{
            .handle = handle,
            .width = width,
            .height = height,
            .data = std.heap.c_allocator.alloc(usize, 24) catch unreachable,
        };
    }

    pub fn deinit(self: *Window) void {
        c.RGFW_window_close(self.handle);
        std.heap.c_allocator.free(self.data);
    }
};
pub const RGFW_windowFlags = enum(u32) {
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
