const std = @import("std");

pub const UNICODE = true;
const win32 = @import("win32").everything;
const L = win32.L;
const HWND = win32.HWND;

const kb = @import("../keyboard.zig");

pub fn convertKeyboard(vk: u32) kb.Key {
    return switch (vk) {
        0 => {},
        else => {
            return kb.Key{ .unknown = vk };
        },
    };
}
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
    keys_pressed: std.AutoHashMap(u32, bool),
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
            .lpszMenuName = L("Some Menu Name"),
            .lpszClassName = class_name,
        };
        if (0 == win32.RegisterClassW(&wc)) {
            win32.panicWin32("RegisterClass", win32.GetLastError());
        }

        // Initialize self BEFORE creating the window
        self.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .class_name = class_name,
            .title = title,
            .title_w = title_w,
            .hwnd = undefined, // Will be set after CreateWindowExW
            .should_close = false,
            .last_msg = undefined,
            .wc = wc,
            .keys_pressed = std.AutoHashMap(u32, bool).init(allocator),
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
            @ptrCast(self), // Pass self as lpParam - available in WM_CREATE
        ) orelse win32.panicWin32("CreateWindow", win32.GetLastError());

        self.hwnd = hwnd;

        // This ensures it's set for all future messages
        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(self)));

        _ = win32.ShowWindow(hwnd, .{ .SHOWNORMAL = 1 });

        return self;
    }

    pub fn getNativeHandle(self: *Backend) *anyopaque {
        return @ptrCast(self.hwnd);
    }

    pub fn deinit(self: *Backend) void {
        _ = win32.DestroyWindow(self.hwnd);
        _ = win32.UnregisterClassW(self.class_name, null);

        self.allocator.free(self.class_name);
        self.allocator.free(self.title_w);
        self.keys_pressed.deinit();

        self.allocator.destroy(self);
    }

    pub fn update(self: *Backend) void {
        const result = win32.GetMessageW(&self.last_msg, null, 0, 0);
        if (result == 0) {
            // WM_QUIT was received
            self.should_close = true;
            return;
        }
        if (result > 0) {
            _ = win32.TranslateMessage(&self.last_msg);
            _ = win32.DispatchMessageW(&self.last_msg);
        }
        // If result < 0, there was an error (you might want to handle this)
    }

    pub fn shouldClose(self: *Backend) bool {
        return self.should_close;
    }
};

fn WindowProc(
    hwnd: HWND,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(.winapi) win32.LRESULT {
    // Handle WM_CREATE specially to set up the user data
    if (uMsg == win32.WM_CREATE) {
        const create_struct: *win32.CREATESTRUCTW = @ptrFromInt(@as(usize, @intCast(lParam)));
        const self: *Backend = @ptrCast(@alignCast(create_struct.lpCreateParams));
        _ = win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, @intCast(@intFromPtr(self)));
        return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
    }

    // Get the Backend pointer
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
        win32.WM_KEYDOWN => {
            if (self) |s| {
                s.keys_pressed.put(@intCast(wParam), true) catch {};
                std.debug.print("Key pressed: {}\n", .{wParam});
            }
            return 0;
        },
        win32.WM_KEYUP => {
            if (self) |s| {
                s.keys_pressed.put(@intCast(wParam), false) catch {};
            }
            return 0;
        },
        win32.WM_PAINT => {
            var ps: win32.PAINTSTRUCT = undefined;
            const hdc = win32.BeginPaint(hwnd, &ps);
            _ = win32.FillRect(hdc, &ps.rcPaint, @ptrFromInt(@intFromEnum(win32.COLOR_WINDOW) + 1));
            _ = win32.TextOutA(hdc, 20, 20, "Hello", 5);
            _ = win32.EndPaint(hwnd, &ps);
            return 0;
        },
        else => {},
    }
    return win32.DefWindowProcW(hwnd, uMsg, wParam, lParam);
}
