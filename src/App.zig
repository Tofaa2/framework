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
    };
    app.resources.add(Time{}) catch unreachable;
    app.resources.add(root.platform.Window.init(config.name, config.width, config.height)) catch unreachable;
    app.resources.add(root.renderer.Renderer.init(
        config.allocators.generic,
        .{ .width = config.width, .height = config.height },
        app.resources.getMut(root.platform.Window).?.getNativePtr(),
        config.debug,
    ) catch unreachable) catch unreachable;

    app.resources.add(root.primitive.FpsCounter{}) catch unreachable;
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
        if (self.resources.getMut(root.platform.Window)) |wind| {
            wind.update();
            if (wind.resized_last_frame) {
                const r_ptr = self.resources.getMut(root.renderer.Renderer);
                if (r_ptr) |renderer| {
                    renderer.resize(wind.width, wind.height);
                }
            }
            self.running = !wind.shouldClose();
        }
        self.scheduler.run(self, .update);
        self.scheduler.run(self, .render);

        const r_ptr = self.resources.getMut(root.renderer.Renderer);
        if (r_ptr) |renderer| {
            self.renderPrimitive(r_ptr.?);
            renderer.draw();
        }

        self.updateFps();
        self.enforceFpsLimit();
        _ = self.allocators.frame_arena.reset(.retain_capacity);
    }
}
fn renderPrimitive(self: *Self, renderer: *root.renderer.Renderer) void {
    var query = self.world.view(.{ root.primitive.Transform, root.primitive.Renderable }, .{});
    var iter = query.entityIterator();
    const view_2d = renderer.getView(.@"2d").?;
    const allocator = self.allocators.generic;

    var builder = root.renderer.MeshBuilder.init(allocator);
    defer builder.deinit();

    // pass 1: untextured
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
                // build at origin, transform moves it
                builder.pushCircle(0.0, 0.0, circle.radius, segments, tint);
                builder.submitTransient(view_2d, null, null, transform.toMatrix());
                builder.reset();
            },
            .rect => |rect| {
                // centered at origin
                builder.pushRect(-rect.width * 0.5, -rect.height * 0.5, rect.width, rect.height, tint);
                builder.submitTransient(view_2d, null, null, transform.toMatrix());
                builder.reset();
            },
            else => {},
        }
    }

    // pass 2: textured
    iter = query.entityIterator();
    while (iter.next()) |entity| {
        const transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);
        var tint: root.primitive.Color = .white;
        if (self.world.tryGetConst(root.primitive.Color, entity)) |color| {
            tint = color;
        }
        switch (renderable) {
            .sprite => |sprite| {
                const w = @as(f32, @floatFromInt(sprite.image.width));
                const h = @as(f32, @floatFromInt(sprite.image.height));
                builder.pushTexturedRect(-w * 0.5, -h * 0.5, w, h, tint);
                builder.submitTransient(view_2d, null, sprite.image, transform.toMatrix());
                builder.reset();
            },
            .text => |t| {
                builder.pushText(t.font, t.content, 0.0, 0.0, tint);
                builder.submitTransient(view_2d, null, &t.font.atlas, transform.toMatrix());
                builder.reset();
            },
            .fmt_text => |*t| {
                const text = t.format_fn(t.buf, self);
                builder.pushText(t.font, text, 0.0, 0.0, tint);
                builder.submitTransient(view_2d, null, &t.font.atlas, transform.toMatrix());
                builder.reset();
            },
            else => {},
        }
    }

    // pass 3: 3D meshes
    const view_3d = renderer.getView(.@"3d").?;
    iter = query.entityIterator();
    while (iter.next()) |entity| {
        var transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);
        switch (renderable) {
            .mesh => |*m| {
                m.mesh.transform = transform.toMatrix();
                view_3d.addMesh(m.mesh);
            },
            else => {},
        }
    }
}
fn renderPrimitive0(self: *Self, renderer: *root.renderer.Renderer) void {
    var query = self.world.view(.{ root.primitive.Transform, root.primitive.Renderable }, .{});
    var iter = query.entityIterator();
    const view = renderer.getView(.@"2d").?;
    const allocator = self.allocators.generic;

    var builder = root.renderer.MeshBuilder.init(allocator);
    defer builder.deinit();

    // pass 1: all untextured geometry (circles, rects, lines)
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
                builder.pushCircle(transform.center[0], transform.center[1], circle.radius, segments, tint);
            },
            .rect => |rect| {
                builder.pushRect(transform.center[0], transform.center[1], rect.width, rect.height, tint);
            },
            else => {},
        }
    }
    builder.submitTransient(view, null, null, null);
    builder.reset();

    // pass 2: textured geometry grouped by texture
    // reset iterator
    iter = query.entityIterator();
    while (iter.next()) |entity| {
        const transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);
        var tint: root.primitive.Color = .white;
        if (self.world.tryGetConst(root.primitive.Color, entity)) |color| {
            tint = color;
        }
        switch (renderable) {
            .sprite => |sprite| {
                const w = @as(f32, @floatFromInt(sprite.image.width));
                const h = @as(f32, @floatFromInt(sprite.image.height));
                builder.pushTexturedRect(
                    transform.center[0] - w * 0.5,
                    transform.center[1] - h * 0.5,
                    w,
                    h,
                    tint,
                );
                builder.submitTransient(view, null, sprite.image, null);
                builder.reset();
            },
            .text => |t| {
                builder.pushText(t.font, t.content, transform.center[0], transform.center[1], tint);
                builder.submitTransient(view, null, &t.font.atlas, null);
                builder.reset();
            },
            .fmt_text => |*t| {
                const text = t.format_fn(t.buf, self);
                builder.pushText(t.font, text, transform.center[0], transform.center[1], tint);
                builder.submitTransient(view, null, &t.font.atlas, null);
                builder.reset();
            },
            else => {},
        }
    }
}

fn updateFps(app: *Self) void {
    const time = app.resources.get(Time).?;
    app.resources.getMut(root.primitive.FpsCounter).?.update(@floatCast(time.delta));
}
fn updateTime(self: *Self) void {
    var time = self.resources.getMut(Time);
    time.?.update(std.time.nanoTimestamp());
}

fn enforceFpsLimit(app: *Self) void {
    const time = app.resources.getMut(Time) orelse return;
    const limit = time.fps_limit orelse return;

    const target_ns: u64 = @intFromFloat(1_000_000_000.0 / @as(f64, @floatFromInt(limit)));
    const now: u64 = @intCast(std.time.nanoTimestamp());
    const frame_start: u64 = @intCast(time.last_frame);
    const elapsed = now - frame_start;

    if (elapsed < target_ns) {
        std.Thread.sleep(target_ns - elapsed);
    }
}

pub const Allocators = struct {
    world: Allocator,
    generic: Allocator,
    frame: Allocator,
    frame_arena: std.heap.ArenaAllocator,
};
