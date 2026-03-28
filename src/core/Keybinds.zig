const std = @import("std");
const KeyBinds = @This();
const App = @import("App.zig");
const Window = @import("Window.zig");

/// Callback for a keybind, called with the App instance when the key is triggered.
pub const Callback = *const fn (*App) void;

/// Modifiers for a keybind, specifying which modifier keys must be pressed.
pub const Modifiers = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
};

/// A keybind, specifying a key and optional modifiers, along with callbacks for press, release, and held events.
pub const KeyBind = struct {
    /// The key pressed
    key: Window.Key,
    /// Modifiers required for the keybind to be triggered
    modifiers: Modifiers = .{},
    /// Callback called when the key is pressed
    on_press: ?Callback = null,
    /// Callback called when the key is released
    on_release: ?Callback = null,
    /// Callback called while the key is held down
    on_held: ?Callback = null,
};

binds: std.ArrayList(KeyBind),
allocator: std.mem.Allocator,

/// Initializes a new empty KeyBinds instance.
/// This is called by the App constructor.
pub fn init(allocator: std.mem.Allocator) !*KeyBinds {
    const self = try allocator.create(KeyBinds);
    self.* = .{ .binds = .empty, .allocator = allocator };
    return self;
}

/// Binds a new keybind to the KeyBinds instance.
pub fn bind(self: *KeyBinds, keybind: KeyBind) void {
    self.binds.append(self.allocator, keybind) catch unreachable;
}

/// Updates the keybinds, calling their callbacks as appropriate.
/// This is called by the App update loop.
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

/// Deinitializes the KeyBinds instance, freeing its memory.
pub fn deinit(self: *KeyBinds) void {
    self.binds.deinit(self.allocator);
    self.allocator.destroy(self);
}
