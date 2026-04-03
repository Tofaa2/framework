/// Lean application host. Manages the World, ThreadPool, frame allocator, and plugin lifecycle.
/// Plugins (Modules) are the primary extension point — each calls back into App to register
/// resources, event channels, and systems. Dependency ordering is resolved automatically.
const std = @import("std");
const builtin = @import("builtin");
const World = @import("World.zig");
const ThreadPool = @import("ThreadPool.zig");
const Scheduler = @import("Scheduler.zig");
const Time = @import("Time.zig");
const AssetServer = @import("AssetServer.zig");
const typeIdInt = @import("util/type_id.zig").typeIdInt;
const App = @This();

pub const Config = struct {
    /// Human-readable name used in log output.
    name: []const u8,
    /// Frame allocator size in bytes. Defaults to 4 MiB.
    frame_pool_size: usize = 1024 * 1024 * 4,
};

const PluginDeinitEntry = struct {
    /// Erased pointer to the App (same as self — here for uniformity).
    deinit_fn: *const fn (*App) void,
};

allocator: std.mem.Allocator,
name: []const u8,
running: bool,
debug: bool,

world: World,
thread_pool: ThreadPool,

/// Short-lived scratch allocator, reset every tick. Ideal for per-frame strings/temp slices.
frame_pool: []u8,
frame_fba: std.heap.FixedBufferAllocator,

/// Plugin deinit callbacks, stored in registration order. Called in reverse on App.deinit().
plugin_deinits: std.ArrayListUnmanaged(PluginDeinitEntry),
/// TypeId set — prevents the same plugin from being registered twice.
registered_plugins: std.AutoHashMapUnmanaged(usize, void),

pub fn init(allocator: std.mem.Allocator, config: Config) !*App {
    const self = try allocator.create(App);
    errdefer allocator.destroy(self);

    try ThreadPool.init(&self.thread_pool, allocator);
    errdefer self.thread_pool.deinit();

    try self.world.init(allocator, &self.thread_pool);
    errdefer self.world.deinit();

    const frame_pool = try allocator.alloc(u8, config.frame_pool_size);
    errdefer allocator.free(frame_pool);

    self.allocator = allocator;
    self.name = config.name;
    self.running = false;
    self.debug = builtin.mode == .Debug;
    self.frame_pool = frame_pool;
    self.frame_fba = std.heap.FixedBufferAllocator.init(frame_pool);
    self.plugin_deinits = .{};
    self.registered_plugins = .{};

    self.world.insertResource(Time.init());
    const asset_server = try allocator.create(AssetServer);
    asset_server.init(allocator);
    self.world.insertOwnedResource(AssetServer, asset_server);
    self.world.registry.resources.addBorrowed(App, self) catch {};

    return self;
}

pub fn deinit(self: *App) void {
    var i = self.plugin_deinits.items.len;
    while (i > 0) {
        i -= 1;
        self.plugin_deinits.items[i].deinit_fn(self);
    }
    self.plugin_deinits.deinit(self.allocator);
    self.registered_plugins.deinit(self.allocator);

    self.thread_pool.deinit();
    self.world.deinit();
    self.allocator.free(self.frame_pool);
    self.allocator.destroy(self);
}

/// Register a plugin. If the plugin declares `dependencies`, those are auto-registered first.
/// Registering the same plugin type twice is silently ignored (safe from dependency chains).
pub fn addPlugin(self: *App, comptime P: type) void {
    comptime validatePlugin(P);

    const id = typeIdInt(P);
    if (self.registered_plugins.contains(id)) return;

    // Resolve declared dependencies first (depth-first).
    if (comptime @hasDecl(P, "dependencies")) {
        inline for (P.dependencies) |Dep| {
            self.addPlugin(Dep);
        }
    }

    self.registered_plugins.put(self.allocator, id, {}) catch @panic("OOM in addPlugin");

    P.build(self);

    if (comptime @hasDecl(P, "deinit")) {
        self.plugin_deinits.append(self.allocator, .{
            .deinit_fn = struct {
                fn call(app: *App) void {
                    P.deinit(app);
                }
            }.call,
        }) catch @panic("OOM in addPlugin deinit register");
    }

    if (self.debug) {
        const name = if (@hasDecl(P, "name")) P.name else @typeName(P);
        std.log.debug("[orin] plugin registered: {s}", .{name});
    }
}

/// Register a typed event channel. Safe to call multiple times for the same type.
pub fn addEvent(self: *App, comptime E: type) void {
    self.world.addEvent(E);
}

/// Insert a singleton resource by value.
pub fn insertResource(self: *App, value: anytype) void {
    self.world.insertResource(value);
}

/// Add a system directly without a plugin.
pub fn addSystem(self: *App, func: Scheduler.SystemFn) Scheduler.SystemBuilder {
    return self.world.addSystem(func);
}

/// 4. Reset frame allocator.
pub fn tick(self: *App) void {
    if (self.world.getMutResource(Time)) |t| t.update();
    self.world.updateEvents();
    self.world.scheduler.run(&self.world);
    self.frame_fba.reset();
}

/// Block until App.stop() is called, ticking every iteration.
pub fn run(self: *App) void {
    self.running = true;
    while (self.running) {
        self.tick();
    }
}

pub fn stop(self: *App) void {
    self.running = false;
}

/// Per-frame scratch allocator. Automatically reset each tick.
pub fn frameAllocator(self: *App) std.mem.Allocator {
    return self.frame_fba.allocator();
}

fn validatePlugin(comptime P: type) void {
    if (!@hasDecl(P, "build")) {
        @compileError("Plugin `" ++ @typeName(P) ++ "` must declare: pub fn build(app: *App) void");
    }
    const BuildFn = @TypeOf(P.build);
    const info = @typeInfo(BuildFn);
    if (info != .@"fn") {
        @compileError("Plugin `" ++ @typeName(P) ++ "`.build must be a function");
    }
}
