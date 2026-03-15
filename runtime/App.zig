const Self = @This();
const std = @import("std");
const log = std.log.scoped(.app);
const Resources = @import("ResourcePool.zig");
const Allocator = std.mem.Allocator;
const Scheduler = @import("scheduler.zig").Scheduler(Self, RunPhase);
const PluginManager = @import("plugin.zig").PluginManager(Self);
const ecs = @import("ecs");

pub const RunPhase = enum {
    init,
    update,
    deinit,
};

name: []const u8,
resources: Resources,
allocators: Allocators,
scheduler: Scheduler,
plugins: PluginManager,
world: ecs.Registry,
running: bool,

pub const AppConfig = struct {
    name: []const u8 = "framework-app",
    allocators: Allocators,
};

pub fn init(config: AppConfig) Self {
    return .{
        .name = config.name,
        .resources = Resources.init(config.allocators.generic),
        .allocators = config.allocators,
        .running = false,
        .world = ecs.Registry.init(config.allocators.world),
        .plugins = PluginManager.init(config.allocators.generic),
        .scheduler = Scheduler.init(
            .{ .allocator = config.allocators.generic },
        ) catch unreachable,
    };
}

pub fn deinit(self: *Self) void {
    self.scheduler.run(self, .deinit);
    self.plugins.deinit();

    self.resources.deinit();
}

pub fn run(self: *Self) void {
    if (self.running) {
        std.log.err("Attempted to run framework application {s} but it is already running", .{self.name});
        return;
    }
    self.running = true;

    self.plugins.initPlugins(self);
    self.scheduler.run(self, .init);

    while (self.running) {
        self.scheduler.run(self, .update);
    }
}

pub const Allocators = struct {
    world: Allocator,
    generic: Allocator,
    frame: Allocator,
};
