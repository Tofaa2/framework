const core = @import("root.zig").core;
const root = @import("root.zig");
const Self = @This();
const std = @import("std");
const log = std.log.scoped(.app);
const Resources = core.ResourcePool;
const Allocator = std.mem.Allocator;
const Scheduler = core.Scheduler(Self, RunPhase);
const ecs = @import("ecs");
const Time = @import("root.zig").primitive.Time;

pub const RunPhase = enum {
    init,
    update,
    render,
    deinit,
};

name: []const u8,
resources: Resources,
allocators: Allocators,
scheduler: Scheduler,
world: ecs.Registry,
running: bool,
window: root.platform.Window,
renderer: root.renderer.Renderer,

pub const AppConfig = struct {
    name: []const u8 = "framework-app",
    width: u32 = 800,
    height: u32 = 600,
    debug: bool = false,
    allocators: Allocators,
};

pub fn init(config: AppConfig) Self {
    var app = Self{
        .name = config.name,
        .resources = Resources.init(config.allocators.generic),
        .allocators = config.allocators,
        .running = false,
        .world = ecs.Registry.init(config.allocators.world),
        .scheduler = Scheduler.init(
            .{ .allocator = config.allocators.generic },
        ) catch unreachable,
        .window = root.platform.Window.init(config.name, config.width, config.height),
        .renderer = undefined,
    };
    app.renderer = root.renderer.Renderer.init(
        config.allocators.generic,
        .{ .width = config.width, .height = config.height },
        app.window.getNativePtr(),
        config.debug,
    ) catch unreachable;
    app.resources.add(Time{}) catch unreachable;

    return app;
}

pub fn deinit(self: *Self) void {
    self.scheduler.run(self, .deinit);

    self.resources.deinit();
}

pub fn run(self: *Self) void {
    if (self.running) {
        std.log.err("Attempted to run framework application {s} but it is already running", .{self.name});
        return;
    }
    self.running = true;

    self.scheduler.run(self, .init);

    self.updateTime();

    while (self.running) {
        self.updateTime();
        self.window.update();
        if (self.window.resized_last_frame) {
            self.renderer.resize(self.window.width, self.window.height);
        }
        self.running = !self.window.shouldClose();
        self.scheduler.run(self, .update);
        self.scheduler.run(self, .render);
        self.renderPrimitive();
        self.renderer.draw();
    }
}

fn renderPrimitive(self: *Self) void {
    var query = self.world.view(.{ root.primitive.Transform, root.primitive.Renderable }, .{});
    var iter = query.entityIterator();

    // var batch_3d = self.renderer.getView(.@"3d").?.createBatch();
    while (iter.next()) |entity| {
        const transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);

        var tint: root.primitive.Color = .white;
        if (self.world.tryGetConst(root.primitive.Color, entity)) |color| {
            tint = color;
        }

        switch (renderable) {
            .circle => |circle| {
                const segments: u32 = circle.segments orelse 16;

                var batch_2d = self.renderer.getView(.@"2d").?.createBatch();
                batch_2d.pushCircle(
                    transform.center[0],
                    transform.center[1],
                    circle.radius,
                    segments,
                    tint,
                );
            },
            .rect => |rect| {
                var batch_2d = self.renderer.getView(.@"2d").?.createBatch();
                batch_2d.pushRect(transform.center[0], transform.center[1], rect.width, rect.height, tint);
            },
            .sprite => |sprite| {
                const w = @as(f32, @floatFromInt(sprite.image.width));
                const h = @as(f32, @floatFromInt(sprite.image.height));
                var sprite_batch = self.renderer.getView(.@"2d").?.createBatch();
                sprite_batch.texture = sprite.image;
                sprite_batch.pushTexturedRect(
                    transform.center[0] - w * 0.5,
                    transform.center[1] - h * 0.5,
                    w,
                    h,
                    tint,
                );
            },
            .text => |t| {
                var text_batch = self.renderer.getView(.@"2d").?.createBatch();
                text_batch.texture = &t.font.atlas;
                text_batch.pushText(
                    t.font,
                    t.content,
                    transform.center[0],
                    transform.center[1],
                    tint,
                );
            },
            // else => {
            //     @panic("Not implemented yet!");
            // },
        }
    }
}

fn updateTime(self: *Self) void {
    var time = self.resources.getMut(Time);
    time.?.update(std.time.nanoTimestamp());
}

pub const Allocators = struct {
    world: Allocator,
    generic: Allocator,
    frame: Allocator,
};
