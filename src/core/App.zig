const std = @import("std");
const builtin = @import("builtin");
const App = @This();
const Window = @import("Window.zig");
const AssetPool = @import("AssetPool.zig");
const Time = @import("Time.zig");
const ResourcePool = @import("ResourcePool.zig");
const Renderer = @import("../renderer/root.zig").Renderer;
const ecs = @import("ecs");
const Keybinds = @import("Keybinds.zig");
const SoundManager = @import("SoundManager.zig");

const root = @import("../root.zig");

/// The name of the app, used for logging and window title.
name: []const u8,
/// The pointer to the Window struct thats used for window management.
window: *Window,
/// The pointer to the AssetPool struct thats used for managing assets (Meshes, Fonts, etc).
assets: *AssetPool,
/// The pointer to the ResourcePool struct thats used for managing resources (Game state, etc).
resources: *ResourcePool,
/// The time struct thats used for tracking start time, delta, frame count, frame time and others.
time: Time,
/// The pointer to the Renderer struct thats used for rendering the scene.
/// Can be used to access the renderer's viewport, materials, and other rendering properties.
/// This can be used to supply meshes and other render primitives directly to the renderer without having to use the entity component system.
renderer: *Renderer,
/// The pointer to the World struct thats used for managing entities and their components.
world: *root.World,
/// The pointer to the EventManager struct thats used for managing events. WIP.
event: *root.EventManager,
/// The pointer to the app lived keybinds. This is a higher level abstraction over the raw keyboard data.
keybinds: *Keybinds,
/// The pointer to the SoundManager struct thats used for managing sounds.
sounds: *SoundManager,
/// The allocator used for heap allocations throughout the App. Hot spots per frame are allocated from the frame pool, not this one.
allocator: std.mem.Allocator,

/// Raw frame pool. Defaults to 6mb.
frame_pool: []u8, // 6mb
/// The backend allocator for the frame pool.
frame_allocator: std.heap.FixedBufferAllocator,

/// Whether debug mode is enabled.
debug: bool,
/// Whether the app is currently running.
running: bool,

/// Initialize an application with a given root allocator and a configuration.
/// This will heap allocate the app struct and its internal components.
/// Call run to start the application loop after initialization is successful.
pub fn init(allocator: std.mem.Allocator, config: AppConfig) !*App {
    const win = try Window.init(allocator, config.name, config.width, config.height);
    const asset_pool = try AssetPool.init(allocator);
    const resources = try ResourcePool.init(allocator);
    const renderer = try allocator.create(Renderer);
    const keybinds = try Keybinds.init(allocator);
    const sounds = try SoundManager.init(allocator);
    const event = root.EventManager.init(allocator);
    try Renderer.init(
        renderer,
        allocator,
        .{ .height = config.height, .width = config.width },
        win.getNativePtr(),
        win.getNativeNdt(),
    );

    const frame_pool = try allocator.alloc(u8, 1024 * 1024 * 6);
    const frame_allocator = std.heap.FixedBufferAllocator.init(frame_pool);

    const app = try allocator.create(App);
    app.* = .{
        .name = config.name,
        .window = win,
        .event = event,
        .assets = asset_pool,
        .resources = resources,
        .renderer = renderer,
        .keybinds = keybinds,
        .running = false,
        .time = Time.init(),
        .world = root.World.init(allocator),
        .debug = builtin.mode == .Debug,
        .allocator = allocator,
        .frame_allocator = frame_allocator,
        .frame_pool = frame_pool,
        .sounds = sounds,
    };
    app.world.ctx = app;

    app.addPlugin(root.RenderSystem.RenderPlugin);
    app.addPlugin(root.AudioSystem.AudioPlugin);
    app.addPlugin(root.PhysicsSystem.PhysicsPlugin);

    return app;
}

/// Deinitialize the application and free all resources.
pub fn deinit(self: *App) void {
    self.window.deinit(self.allocator);
    self.assets.deinit(self.allocator);
    self.renderer.deinit();
    self.resources.deinit();
    self.allocator.free(self.frame_pool);
    self.world.deinit();
    self.keybinds.deinit();
    self.sounds.deinit();
    self.event.deinit();
    self.allocator.destroy(self);
}

/// Very primitive "plugin" system for adding functionality to the App.
/// Foundational plugins can be found in the root module (root.RenderSystem, root.AudioSystem, root.PhysicsSystem).
pub fn addPlugin(self: *App, plugin: root.Plugin) void {
    plugin.build(self);
}

/// Get the frame allocator for the application.
/// This is the preferred way to do per-frame short lived allocations
/// Such as allocating formattable text.
pub fn getFrameAllocator(self: *App) std.mem.Allocator {
    return self.frame_allocator.allocator();
}

/// Run the application. This function is blocking until App#running is set to false.
pub fn run(self: *App) void {
    if (self.running) {
        std.log.err("App {s} is already running!\n", .{self.name});
        return;
    }
    if (self.debug) {
        std.log.info("Running app {s} in debug mode\n", .{self.name});
    }
    self.running = true;
    self.time.update();

    while (self.running) {
        self.time.update();
        self.window.update();
        if (self.window.resized_last_frame) {
            self.renderer.resize(self.window.width, self.window.height);
        }
        self.keybinds.update(self);

        self.world.scheduler.run(self.world);
        self.renderer.draw(self.assets);
        self.event.dispatch(.update);
        self.time.enforceFpsLimit();
        self.running = !self.window.shouldClose();
        self.frame_allocator.reset();
    }
}

/// App configuration struct, this is used to configure the app on initialization.
pub const AppConfig = struct {
    /// The name of the app, used for logging and window title.
    name: []const u8,
    /// The base width of the app window. This also sets the framebuffer width.
    width: u32,
    /// The base height of the app window. This also sets the framebuffer height.
    height: u32,
};

/// App initialization error type.
pub const AppError = error{
    /// Failed to initialize the window.
    WindowInitFailed,
    /// Failed to allocate the App struct and its internals.
    OutOfMemory,
    /// Failed to initialize the assets.
    AssetInitFailed,
};
