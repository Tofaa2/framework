const std = @import("std");

pub const UNICODE = true;
const win32 = @import("win32").everything;
const L = win32.L;
const HWND = win32.HWND;

const kb = @import("../input.zig");
const win32_keys = @import("win32_keys.zig");

// ============================================================================
// Windows Backend
// ============================================================================
pub const Backend = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    title: []const u8,
    title_w: [:0]const u16,
    class_name: [:0]const u16,
    hwnd: HWND,
    wc: win32.WNDCLASSW,
    should_close: bool,
    last_msg: win32.MSG,
    input: *kb.InputState,

    pub fn init(
        allocator: std.mem.Allocator,
        title: []const u8,
        width: u32,
        height: u32,
    ) *Backend {
        const self = allocator.create(Backend) catch unreachable;
        errdefer allocator.destroy(self);

        const class_name = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch unreachable;
        const title_w = std.unicode.utf8ToUtf16LeAllocZ(allocator, title) catch unreachable;

        const wc = win32.WNDCLASSW{
            .style = .{},
            .lpfnWndProc = WindowProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = null,
            .hIcon = null,
            .hCursor = null,
            .hbrBackground = null,
            .lpszMenuName = L(""),
            .lpszClassName = class_name,
        };
        if (0 == win32.RegisterClassW(&wc)) {
            win32.panicWin32("RegisterClass", win32.GetLastError());
        }

        const input_state = kb.InputState.init(allocator) catch unreachable;
        errdefer input_state.deinit();

        self.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .class_name = class_name,
            .title = title,
            .title_w = title_w,
            .hwnd = undefined,
            .should_close = false,
            .last_msg = undefined,
            .wc = wc,
            .input = input_state,
        };

        const hwnd = win32.CreateWindowExW(
            .{},
            class_name,
            title_w,
            win32.WS_OVERLAPPEDWINDOW,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            @intCast(width),
            @intCast(height),
            null,
            null,
            null,
            @ptrCast(self),
        ) orelse win32.panicWin32("CreateWindow", win32.GetLastError());

        self.hwnd = hwnd;
        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(self)));
        _ = win32.ShowWindow(hwnd, .{ .SHOWNORMAL = 1 });
        _ = win32.UpdateWindow(hwnd);
        return self;
    }

    pub fn getNativeHandle(self: *Backend) *anyopaque {
        return @ptrCast(self.hwnd);
    }

    pub fn getWin32ModuleHandle(_: *Backend) ?*anyopaque {
        return win32.GetModuleHandleW(null);
    }

    pub fn deinit(self: *Backend) void {
        _ = win32.DestroyWindow(self.hwnd);
        _ = win32.UnregisterClassW(self.class_name, null);

        self.allocator.free(self.class_name);
        self.allocator.free(self.title_w);
        self.input.deinit();

        self.allocator.destroy(self);
    }

    pub fn update(self: *Backend) void {
        // Begin new input frame
        self.input.beginFrame();

        // Process all pending messages
        var msg: win32.MSG = undefined;
        while (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            if (msg.message == win32.WM_QUIT) {
                self.should_close = true;
                return;
            }
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageW(&msg);
        }
    }

    pub fn shouldClose(self: *Backend) bool {
        return self.should_close;
    }

    pub fn getInput(self: *Backend) *kb.InputState {
        return self.input;
    }

    pub fn setMouseLockState(self: *Backend, value: bool) void {
        if (!value) {
            _ = win32.ClipCursor(null);
        }else {
            const hwnd = self.hwnd;
            var rect: win32.RECT = undefined;
            _ = win32.GetClientRect(hwnd, &rect);

            var top_left = win32.POINT{
                .x = rect.left,
                .y = rect.top,
            };
            var bottom_right = win32.POINT{
                .x = rect.right,
                .y = rect.bottom,
            };

            _ = win32.ClientToScreen(hwnd, &top_left);
            _ = win32.ClientToScreen(hwnd, &bottom_right);

            var screen_rect = win32.RECT{
                .left = top_left.x,
                .top = top_left.y,
                .right = bottom_right.x,
                .bottom = bottom_right.y,
            };
            _ = win32.ClipCursor(&screen_rect);
        }
    }

};

// ============================================================================
// Window Procedure
// ============================================================================

fn WindowProc(
    hwnd: HWND,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(.winapi) win32.LRESULT {
    if (uMsg == win32.WM_CREATE) {
        const create_struct: *win32.CREATESTRUCTW = @ptrFromInt(@as(usize, @intCast(lParam)));
        const self: *Backend = @ptrCast(@alignCast(create_struct.lpCreateParams));
        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(self)));
        return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
    }

    const raw = win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA);
    const self: ?*Backend = if (raw != 0) @ptrFromInt(@as(usize, @intCast(raw))) else null;

    switch (uMsg) {
        win32.WM_DESTROY => {
            if (self) |s| {
                s.should_close = true;
            }
            win32.PostQuitMessage(0);
            return 0;
        },

        // win32.WM_PAINT => {
        //     var ps: win32.PAINTSTRUCT = undefined;
        //     const hdc = win32.BeginPaint(hwnd, &ps);
        //     _ = win32.FillRect(hdc, &ps.rcPaint, @ptrFromInt(@intFromEnum(win32.COLOR_WINDOW) + 1));
        //     _ = win32.EndPaint(hwnd, &ps);
        //     return 0;
        // },

        // ====================================================================
        // Keyboard Events
        // ====================================================================

        win32.WM_KEYDOWN, win32.WM_SYSKEYDOWN => {
            if (self) |s| {
                const vk: u16 = @truncate(wParam);
                const flags: u32 = @bitCast(@as(u32, @truncate(@as(usize, @bitCast(lParam)))));
                const repeat = (flags & 0x40000000) != 0;

                const extended_vk = win32_keys.getExtendedKeyCode(vk, flags);
                const key = win32_keys.win32VKToKey(extended_vk);

                if (key != .Unknown) {
                    const state: kb.KeyState = if (repeat) .Repeat else .Pressed;
                    s.input.handleKeyEvent(key, state) catch {};
                }
            }

            // Let Alt+F4 and other system keys through
            if (uMsg == win32.WM_SYSKEYDOWN) {
                return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
            }
            return 0;
        },

        win32.WM_KEYUP, win32.WM_SYSKEYUP => {
            if (self) |s| {
                const vk: u16 = @truncate(wParam);
                const flags: u32 = @bitCast(@as(u32, @truncate(@as(usize, @bitCast(lParam)))));

                const extended_vk = win32_keys.getExtendedKeyCode(vk, flags);
                const key = win32_keys.win32VKToKey(extended_vk);

                if (key != .Unknown) {
                    s.input.handleKeyEvent(key, .Released) catch {};
                }
            }

            if (uMsg == win32.WM_SYSKEYUP) {
                return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
            }
            return 0;
        },

        // ====================================================================
        // Mouse Button Events
        // ====================================================================

        win32.WM_LBUTTONDOWN => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Left, .Pressed) catch {};
            }
            return 0;
        },

        win32.WM_LBUTTONUP => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Left, .Released) catch {};
            }
            return 0;
        },

        win32.WM_RBUTTONDOWN => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Right, .Pressed) catch {};
            }
            return 0;
        },

        win32.WM_RBUTTONUP => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Right, .Released) catch {};
            }
            return 0;
        },

        win32.WM_MBUTTONDOWN => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Middle, .Pressed) catch {};
            }
            return 0;
        },

        win32.WM_MBUTTONUP => {
            if (self) |s| {
                s.input.handleMouseButtonEvent(.Middle, .Released) catch {};
            }
            return 0;
        },

        win32.WM_XBUTTONDOWN => {
            if (self) |s| {
                const button_id = (wParam >> 16) & 0xFFFF;
                const button: kb.MouseButton = if (button_id == 1) .X1 else .X2;
                s.input.handleMouseButtonEvent(button, .Pressed) catch {};
            }
            return 1; // Indicate we handled the message
        },

        win32.WM_XBUTTONUP => {
            if (self) |s| {
                const button_id = (wParam >> 16) & 0xFFFF;
                const button: kb.MouseButton = if (button_id == 1) .X1 else .X2;
                s.input.handleMouseButtonEvent(button, .Released) catch {};
            }
            return 1;
        },

        // ====================================================================
        // Mouse Movement
        // ====================================================================

        win32.WM_MOUSEMOVE => {
            if (self) |s| {
                const x: i32 = @as(i16, @truncate(lParam & 0xFFFF));
                const y: i32 = @as(i16, @truncate((lParam >> 16) & 0xFFFF));
                s.input.handleMouseMove(x, y) catch {};
            }
            return 0;
        },

        // ====================================================================
        // Mouse Wheel
        // ====================================================================

        win32.WM_MOUSEWHEEL => {
            if (self) |s| {
                const delta: i16 = @bitCast(@as(u16, @truncate(wParam >> 16)));
                const wheel_delta: f32 = @as(f32, @floatFromInt(delta)) / 120.0;
                s.input.handleMouseScroll(0, wheel_delta) catch {};
            }
            return 0;
        },
        win32.WM_MOUSEHWHEEL => {
            if (self) |s| {
                const delta: i16 = @bitCast(@as(u16, @truncate(wParam >> 16)));
                const wheel_delta: f32 = @as(f32, @floatFromInt(delta)) / 120.0;
                s.input.handleMouseScroll(wheel_delta, 0) catch {};
            }
            return 0;
        },

        else => {},
    }

    return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
}
