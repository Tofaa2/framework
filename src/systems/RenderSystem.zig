const std = @import("std");
const root = @import("../root.zig");

fn resolvePosition(world: *root.World, entity: anytype, transform: root.Transform, renderer: *root.Renderer) [2]f32 {
    if (world.tryGetConst(root.Anchor, entity)) |anchor| {
        const w: f32 = @floatFromInt(renderer.viewport.width);
        const h: f32 = @floatFromInt(renderer.viewport.height);
        const pos = anchor.resolve(w, h);
        return .{ pos[0] + anchor.offset[0], pos[1] + anchor.offset[1] };
    }
    return .{ transform.center[0], transform.center[1] };
}

fn updateLights(world: *root.World, renderer: *root.Renderer, app: *root.App) void {
    const ambient = app.resources.get(root.AmbientLight) orelse &root.AmbientLight{};
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

    var light_query = world.view(.{ root.Transform, root.Light }, .{});
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

fn render2D(world: *root.World, builder: *root.MeshBuilder, app: *root.App) void {
    const view_2d = app.renderer.getView(.@"2d").?;
    var query = world.view(.{ root.Transform, root.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.Transform, entity);
        const renderable = query.getConst(root.Renderable, entity);
        const pos = resolvePosition(world, entity, transform, app.renderer);
        var tint: root.Color = .white;
        if (world.tryGetConst(root.Color, entity)) |color| tint = color;

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
                const image = app.assets.getAsset(root.Image, sprite.image) orelse continue;

                const w: f32 = @floatFromInt(image.width);
                const h: f32 = @floatFromInt(image.height);
                builder.pushTexturedRect(pos[0] - w * 0.5, pos[1] - h * 0.5, w, h, tint);
                builder.submitTransient(view_2d, null, image, null, false);
                builder.reset();
            },
            .text => |t| {
                const font = app.assets.getAsset(root.Font, t.font).?;
                builder.pushText(font, t.content, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &font.atlas, null, true);
                builder.reset();
            },
            .fmt_text => |*t| {
                const font = app.assets.getAsset(root.Font, t.font).?;
                const text = t.format_fn(t.buf, app);
                builder.pushText(font, text, pos[0], pos[1], tint);
                builder.submitTransient(view_2d, null, &font.atlas, null, true);
                builder.reset();
            },
            else => {},
        }
    }
}

fn render3D(world: *root.World, app: *root.App) void {
    const view_3d = app.renderer.getView(.@"3d") orelse return;
    view_3d.render_commands.clearRetainingCapacity();

    var query = world.view(.{ root.Transform, root.Renderable }, .{});
    var iter = query.entityIterator();

    while (iter.next()) |entity| {
        const transform = query.getConst(root.Transform, entity);
        const renderable = query.getConst(root.Renderable, entity);
        switch (renderable) {
            .mesh => |m| {
                if (app.assets.getAsset(root.Mesh, m.mesh)) |mesh| {
                    if (mesh.material == null) {
                        mesh.material = app.renderer.getMaterial(.diffuse);
                    }
                    view_3d.render_commands.append(view_3d.allocator, .{
                        .mesh = mesh,
                        .transform = transform.toMatrix(),
                    }) catch unreachable;
                }
            },
            else => {},
        }
    }
}

pub const RenderPlugin = root.Plugin.init(plugin_build);

fn plugin_build(app: *root.App) void {
    app.world.scheduler.buildSystem(renderSystem)
        .reads(root.Transform)
        .reads(root.Renderable)
        .reads(root.Light)
        .reads(root.Anchor)
        .reads(root.Color)
        .reads(root.AmbientLight)
        .inPhase(.render)
        .append();
}

fn renderSystem(world: *root.World) void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));
    const renderer = app.renderer;

    updateLights(world, renderer, app);

    var builder = root.MeshBuilder.init(app.allocator);
    defer builder.deinit();

    render2D(world, &builder, app);
    render3D(world, app);
}


