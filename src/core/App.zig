const std = @import("std");
const builtin = @import("builtin");
const App = @This();
const Window = @import("Window.zig");
const AssetPool = @import("AssetPool.zig");
const Scheduler = @import("Scheduler.zig");
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
scheduler: *Scheduler,
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
    const scheduler = try Scheduler.init(allocator);
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
        .scheduler = scheduler,
        .resources = resources,
        .renderer = renderer,
        .keybinds = keybinds,
        .running = false,
        .time = Time.init(),
        // .world = ecs.Registry.init(allocator),
        .world = root.World.init(allocator),
        .debug = builtin.mode == .Debug,
        .allocator = allocator,
        .frame_allocator = frame_allocator,
        .frame_pool = frame_pool,
        .sounds = sounds,
    };
    return app;
}

pub fn deinit(self: *App) void {
    self.window.deinit(self.allocator);
    self.assets.deinit(self.allocator);
    self.scheduler.deinit();
    self.renderer.deinit();
    self.resources.deinit();
    self.world.deinit();
    self.keybinds.deinit();
    self.sounds.deinit();
    self.event.deinit();
    self.allocator.destroy(self);
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
    self.scheduler.run(self, .init);
    self.time.update();
    while (self.running) {
        self.time.update();
        self.window.update();
        if (self.window.resized_last_frame) {
            self.renderer.resize(self.window.width, self.window.height);
        }
        self.updateSounds();
        self.scheduler.run(self, .update);
        self.keybinds.update(self);
        self.scheduler.run(self, .input);

        self.scheduler.run(self, .physics);

        self.renderPrimitive();
        self.scheduler.run(self, .render);
        self.renderer.draw(self.assets);

        self.world.scheduler.run(self.world);
        self.event.dispatch(.update);
        self.time.enforceFpsLimit();
        self.running = !self.window.shouldClose();

        self.frame_allocator.reset();
    }
}
fn updateSounds(self: *App) void {
    self.sounds.update();

    var query = self.world.basicView(root.SoundSource);
    var iter = query.mutIterator();
    while (iter.next()) |ss| {
        if (!ss.sound.isValid()) continue;

        if (ss.internal_handle == root.SoundSource.INVALID_HANDLE) {
            const sound = self.assets.getAsset(root.Sound, ss.sound);
            if (sound) |s| {
                ss.internal_handle = self.sounds.play(s, ss.volume, ss.pitch) catch |err| {
                    std.log.err("Failed to play sound: {}", .{err});
                    continue;
                };
            }
        } else {
            self.sounds.setVolume(ss.internal_handle, ss.volume);
            self.sounds.setPitch(ss.internal_handle, ss.pitch);

            if (!self.sounds.isPlaying(ss.internal_handle)) {
                if (ss.looping) {
                    ss.internal_handle = root.SoundSource.INVALID_HANDLE;
                } else {
                    ss.sound = root.Handle(root.Sound).invalid;
                    ss.internal_handle = root.SoundSource.INVALID_HANDLE;
                }
            }
        }
    }
}
fn render2D(self: *App, builder: *root.MeshBuilder) void {
    const view_2d = self.renderer.getView(.@"2d").?;
    var query = self.world.view(.{ root.Transform, root.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.Transform, entity);
        const renderable = query.getConst(root.Renderable, entity);
        const pos = self.resolvePosition(entity, transform, self.renderer);
        var tint: root.Color = .white;
        if (self.world.tryGetConst(root.Color, entity)) |color| tint = color;

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
                const image = self.assets.getAsset(root.Image, sprite.image) orelse return;

                const w: f32 = @floatFromInt(image.width);
                const h: f32 = @floatFromInt(image.height);
                builder.pushTexturedRect(pos[0] - w * 0.5, pos[1] - h * 0.5, w, h, tint);
                builder.submitTransient(view_2d, null, image, null, false);
                builder.reset();
            },
            .text => |t| {
                const font = self.assets.getAsset(root.Font, t.font).?;
                builder.pushText(font, t.content, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &font.atlas, null, true);
                builder.reset();
            },
            .fmt_text => |*t| {
                const font = self.assets.getAsset(root.Font, t.font).?;
                const text = t.format_fn(t.buf, self);
                builder.pushText(font, text, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &font.atlas, null, true);
                builder.reset();
            },
            else => {},
        }
    }
}

fn render3D(self: *App) void {
    const view_3d = self.renderer.getView(.@"3d").?;
    var query = self.world.view(.{ root.Transform, root.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.Transform, entity);
        const renderable = query.getConst(root.Renderable, entity);
        switch (renderable) {
            .mesh => |m| {
                const mesh = self.assets.getAsset(root.Mesh, m.mesh).?;
                mesh.transform = transform.toMatrix();
                if (mesh.material == null) {
                    mesh.material = self.renderer.getMaterial(.diffuse);
                }
                view_3d.addMesh(mesh);
            },
            else => {},
        }
    }
}

fn renderPrimitive(self: *App) void {
    const renderer = self.renderer;
    self.updateLights(renderer);

    var builder = root.MeshBuilder.init(self.allocator);
    defer builder.deinit();

    self.render2D(&builder);
    self.render3D();
}
fn updateLights(self: *App, renderer: *root.Renderer) void {
    const ambient = self.resources.get(root.AmbientLight) orelse &root.AmbientLight{};
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

    var light_query = self.world.view(.{ root.Transform, root.Light }, .{});
    var light_iter = light_query.entityIterator();
    while (light_iter.next()) |entity| {
        if (light_count >= MAX_LIGHTS) break;
        const transform = light_query.getConst(root.Transform, entity);
        const light = light_query.getConst(root.Light, entity);
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

fn resolvePosition(self: *App, entity: anytype, transform: root.Transform, renderer: *root.Renderer) [2]f32 {
    if (self.world.tryGetConst(root.Anchor, entity)) |anchor| {
        const w: f32 = @floatFromInt(renderer.viewport.width);
        const h: f32 = @floatFromInt(renderer.viewport.height);
        const pos = anchor.resolve(w, h);
        return .{ pos[0] + anchor.offset[0], pos[1] + anchor.offset[1] };
    }
    return .{ transform.center[0], transform.center[1] };
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
