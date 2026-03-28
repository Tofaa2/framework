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

name: []const u8,
window: *Window,
assets: *AssetPool,
resources: *ResourcePool,
time: Time,
renderer: *Renderer,
world: *root.World,
event: *root.EventManager,
keybinds: *Keybinds,
sounds: *SoundManager,
allocator: std.mem.Allocator,

frame_pool: [1024 * 1024 * 6]u8, // 6mb
frame_allocator: std.heap.FixedBufferAllocator,

debug: bool,
running: bool,

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

    var frame_pool: [1024 * 1024 * 6]u8 = undefined;
    const frame_allocator = std.heap.FixedBufferAllocator.init(&frame_pool);

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

pub fn deinit(self: *App) void {
    self.window.deinit(self.allocator);
    self.assets.deinit(self.allocator);
    self.renderer.deinit();
    self.resources.deinit();
    self.world.deinit();
    self.keybinds.deinit();
    self.sounds.deinit();
    self.event.deinit();
    self.allocator.destroy(self);
}

pub fn addPlugin(self: *App, plugin: root.Plugin) void {
    plugin.build(self);
}

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

pub const AppConfig = struct {
    name: []const u8,
    width: u32,
    height: u32,
};
pub const AppError = error{
    WindowInitFailed,
    OutOfMemory,
    AssetInitFailed,
};
