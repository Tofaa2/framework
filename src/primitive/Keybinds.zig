const std = @import("std");
const runtime = @import("../root.zig");
const window = runtime.platform;
const KeyBinds = @This();

pub const Callback = *const fn (*runtime.App) void;

pub const Modifiers = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
};

pub const KeyBind = struct {
    key: window.RGFW_key,
    modifiers: Modifiers = .{},
    on_press: ?Callback = null,
    on_release: ?Callback = null,
    on_held: ?Callback = null,
};

binds: std.ArrayList(KeyBind),

pub fn init(allocator: std.mem.Allocator) KeyBinds {
    return .{ .binds = .init(allocator) };
}

pub fn bind(self: *KeyBinds, keybind: KeyBind) void {
    self.binds.append(keybind) catch unreachable;
}

pub fn update(self: *KeyBinds, app: *runtime.App) void {
    const win = app.resources.get(window.Window).?;
    for (self.binds.items) |kb| {
        if (win.isKeyPressed(kb.key)) {
            if (kb.on_press) |f| f(app);
        }
        if (win.isKeyHeld(kb.key)) {
            if (kb.on_held) |f| f(app);
        }
        if (win.isKeyReleased(kb.key)) {
            if (kb.on_release) |f| f(app);
        }
    }
}

pub fn deinit(self: *KeyBinds) void {
    self.binds.deinit();
}
