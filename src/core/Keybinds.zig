const std = @import("std");
const KeyBinds = @This();
const App = @import("App.zig");
const Window = @import("Window.zig");

pub const Callback = *const fn (*App) void;

pub const Modifiers = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
};

pub const KeyBind = struct {
    key: Window.Key,
    modifiers: Modifiers = .{},
    on_press: ?Callback = null,
    on_release: ?Callback = null,
    on_held: ?Callback = null,
};

binds: std.ArrayList(KeyBind),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !*KeyBinds {
    const self = try allocator.create(KeyBinds);
    self.* = .{ .binds = .empty, .allocator = allocator };
    return self;
}

pub fn bind(self: *KeyBinds, keybind: KeyBind) void {
    self.binds.append(self.allocator, keybind) catch unreachable;
}

pub fn update(self: *KeyBinds, app: *App) void {
    for (self.binds.items) |kb| {
        if (app.window.isKeyPressed(kb.key)) {
            if (kb.on_press) |f| f(app);
        }
        if (app.window.isKeyDown(kb.key)) {
            if (kb.on_held) |f| f(app);
        }
        if (app.window.isKeyReleased(kb.key)) {
            if (kb.on_release) |f| f(app);
        }
    }
}

pub fn deinit(self: *KeyBinds) void {
    self.binds.deinit(self.allocator);
    self.allocator.destroy(self);
}
