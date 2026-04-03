/// Manages high-level keyboard input mapping and callbacks.
/// Provides a way to bind specific keys and modifiers to application-level actions.
const std = @import("std");
const KeyBinds = @This();
const App = @import("App.zig");
const Window = @import("Window.zig");

/// Callback function type for key events.
/// Takes a pointer to the App instance.
pub const Callback = *const fn (*App) void;

/// Specifies required keyboard modifiers for a binding.
pub const Modifiers = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
};

/// Defines a specific key binding with associated callbacks for different event states.
pub const KeyBind = struct {
    /// The primary key for the binding.
    key: Window.Key,
    /// Modifier keys that must also be held.
    modifiers: Modifiers = .{},
    /// Triggered exactly once when the key state changes to pressed.
    on_press: ?Callback = null,
    /// Triggered exactly once when the key state changes to released.
    on_release: ?Callback = null,
    /// Triggered every frame while the key is held down.
    on_held: ?Callback = null,
};

/// List of all registered keybindings.
binds: std.ArrayList(KeyBind),
/// Allocator for the binding list.
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
