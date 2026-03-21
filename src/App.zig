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
time: Time,
renderer: *root.renderer.Renderer,
window: root.platform.Window,

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
        .scheduler = Scheduler.init(config.allocators.generic) catch unreachable,
        .time = Time.init(),
        .window = root.platform.Window.init(config.name, config.width, config.height),
        .renderer = undefined,
    };

    var renderer = config.allocators.generic.create(root.renderer.Renderer) catch unreachable;
    renderer.init(
        config.allocators.generic,
        .{ .width = config.width, .height = config.height },
        app.window.getNativePtr(),
        app.window.getNativeNdt(),
        config.debug,
    ) catch unreachable;
    app.renderer = renderer;

    app.resources.add(root.primitive.AmbientLight{
        .color = .{ .r = 100, .g = 100, .b = 100, .a = 255 },
    }) catch unreachable;
    return app;
}

pub fn deinit(self: *Self) void {
    self.scheduler.run(self, .deinit);
    self.scheduler.deinit();
    self.world.deinit();
    self.renderer.deinit();
    self.allocators.generic.destroy(self.renderer);
    self.resources.deinit();
}

pub fn run(self: *Self) void {
    if (self.running) {
        std.log.err("Attempted to run framework application {s} but it is already running", .{self.name});
        return;
    }
    self.running = true;

    self.scheduler.run(self, .init);

    self.time.update(std.time.nanoTimestamp());

    while (self.running) {
        self.time.update(std.time.nanoTimestamp());

        self.scheduler.run(self, .update);
        self.window.update();
        if (self.window.resized_last_frame) {
            self.renderer.resize(self.window.width, self.window.height);
        }
        self.scheduler.run(self, .render);

        self.renderPrimitive();
        self.renderer.draw();
        self.time.enforceFpsLimit();
        _ = self.allocators.frame_arena.reset(.retain_capacity);

        self.running = !self.window.shouldClose();
    }
}

pub const Allocators = struct {
    world: Allocator,
    generic: Allocator,
    frame: Allocator,
    frame_arena: std.heap.ArenaAllocator,
};

fn resolvePosition(self: *Self, entity: anytype, transform: root.primitive.Transform, renderer: *root.renderer.Renderer) [2]f32 {
    if (self.world.tryGetConst(root.primitive.Anchor, entity)) |anchor| {
        const w: f32 = @floatFromInt(renderer.viewport.width);
        const h: f32 = @floatFromInt(renderer.viewport.height);
        const pos = anchor.resolve(w, h);
        return .{ pos[0] + anchor.offset[0], pos[1] + anchor.offset[1] };
    }
    return .{ transform.center[0], transform.center[1] };
}

fn updateLights(self: *Self, renderer: *root.renderer.Renderer) void {
    const ambient = self.resources.get(root.primitive.AmbientLight) orelse &root.primitive.AmbientLight{};
    const ambient_color: [4]f32 = .{
        @as(f32, @floatFromInt(ambient.color.r)) / 255.0,
        @as(f32, @floatFromInt(ambient.color.g)) / 255.0,
        @as(f32, @floatFromInt(ambient.color.b)) / 255.0,
        1.0,
    };
    const MAX_LIGHTS = 4;
    var light_dirs: [MAX_LIGHTS][4]f32 = std.mem.zeroes([MAX_LIGHTS][4]f32);
    var light_colors: [MAX_LIGHTS][4]f32 = std.mem.zeroes([MAX_LIGHTS][4]f32);
    var light_count: u32 = 0;

    var light_query = self.world.view(.{ root.primitive.Transform, root.primitive.Light }, .{});
    var light_iter = light_query.entityIterator();
    while (light_iter.next()) |entity| {
        if (light_count >= MAX_LIGHTS) break;
        const transform = light_query.getConst(root.primitive.Transform, entity);
        const light = light_query.getConst(root.primitive.Light, entity);
        const rx = transform.rotation[0];
        const ry = transform.rotation[1];
        light_dirs[light_count] = .{ @cos(rx) * @sin(ry), -@sin(rx), @cos(rx) * @cos(ry), 0.0 };
        light_colors[light_count] = .{
            @as(f32, @floatFromInt(light.color.r)) / 255.0 * light.intensity,
            @as(f32, @floatFromInt(light.color.g)) / 255.0 * light.intensity,
            @as(f32, @floatFromInt(light.color.b)) / 255.0 * light.intensity,
            1.0,
        };
        light_count += 1;
    }

    const diffuse_mat = renderer.getMaterial(.diffuse);
    diffuse_mat.setVec4Array("u_lightDirs", &light_dirs, MAX_LIGHTS);
    diffuse_mat.setVec4Array("u_lightColors", &light_colors, MAX_LIGHTS);
    diffuse_mat.setVec4("u_lightCount", .{ @as(f32, @floatFromInt(light_count)), 0.0, 0.0, 0.0 });
    diffuse_mat.setVec4("u_ambient", ambient_color);
}

fn render2D(self: *Self, renderer: *root.renderer.Renderer, builder: *root.renderer.MeshBuilder) void {
    const view_2d = renderer.getView(.@"2d").?;
    var query = self.world.view(.{ root.primitive.Transform, root.primitive.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);
        const pos = self.resolvePosition(entity, transform, renderer);
        var tint: root.primitive.Color = .white;
        if (self.world.tryGetConst(root.primitive.Color, entity)) |color| tint = color;

        switch (renderable) {
            .circle => |circle| {
                builder.pushCircle(pos[0], pos[1], circle.radius, circle.segments orelse 16, tint);
                builder.submitTransient(view_2d, null, null, null, false);
                builder.reset();
            },
            .rect => |rect| {
                builder.pushRect(pos[0] - rect.width * 0.5, pos[1] - rect.height * 0.5, rect.width, rect.height, tint);
                builder.submitTransient(view_2d, null, null, null, false);
                builder.reset();
            },
            .sprite => |sprite| {
                const w: f32 = @floatFromInt(sprite.image.width);
                const h: f32 = @floatFromInt(sprite.image.height);
                builder.pushTexturedRect(pos[0] - w * 0.5, pos[1] - h * 0.5, w, h, tint);
                builder.submitTransient(view_2d, null, sprite.image, null, false);
                builder.reset();
            },
            .text => |t| {
                builder.pushText(t.font, t.content, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &t.font.atlas, null, true);
                builder.reset();
            },
            .fmt_text => |*t| {
                const text = t.format_fn(t.buf, self);
                builder.pushText(t.font, text, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &t.font.atlas, null, true);
                builder.reset();
            },
            else => {},
        }
    }
}

fn render3D(self: *Self, renderer: *root.renderer.Renderer) void {
    const view_3d = renderer.getView(.@"3d").?;
    var query = self.world.view(.{ root.primitive.Transform, root.primitive.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.primitive.Transform, entity);
        const renderable = query.getConst(root.primitive.Renderable, entity);
        switch (renderable) {
            .mesh => |*m| {
                m.mesh.transform = transform.toMatrix();
                if (m.mesh.material == null) {
                    m.mesh.material = renderer.getMaterial(.diffuse);
                }
                view_3d.addMesh(m.mesh);
            },
            else => {},
        }
    }
}

fn renderPrimitive(self: *Self) void {
    const renderer = self.renderer;
    self.updateLights(renderer);

    var builder = root.renderer.MeshBuilder.init(self.allocators.generic);
    defer builder.deinit();

    self.render2D(renderer, &builder);
    self.render3D(renderer);
}
