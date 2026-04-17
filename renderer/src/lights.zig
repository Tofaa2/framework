const std = @import("std");
const math = @import("math");

pub const DirectionalLight = struct {
    direction: math.Vec3,
    color: math.Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    intensity: f32 = 1.0,
};

pub const PointLight = struct {
    position: math.Vec3,
    color: math.Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    intensity: f32 = 1.0,
    radius: f32 = 10.0,
};

pub const SpotLight = struct {
    position: math.Vec3,
    direction: math.Vec3,
    color: math.Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    intensity: f32 = 1.0,
    inner_angle: f32 = 20.0,
    outer_angle: f32 = 30.0,
    radius: f32 = 20.0,
};

pub const Light = union(enum) {
    dir: DirectionalLight,
    pt: PointLight,
    spotlight: SpotLight,

    pub fn directional(dir: math.Vec3, color: math.Vec3, intensity: f32) Light {
        return .{ .dir = .{
            .direction = math.Vec3.normalize(dir),
            .color = color,
            .intensity = intensity,
        } };
    }

    pub fn point(pos: math.Vec3, color: math.Vec3, intensity: f32, radius: f32) Light {
        return .{ .pt = .{
            .position = pos,
            .color = color,
            .intensity = intensity,
            .radius = radius,
        } };
    }

    pub fn spot(pos: math.Vec3, dir: math.Vec3, color: math.Vec3, intensity: f32, inner_angle: f32, outer_angle: f32, radius: f32) Light {
        return .{ .spotlight = .{
            .position = pos,
            .direction = math.Vec3.normalize(dir),
            .color = color,
            .intensity = intensity,
            .inner_angle = inner_angle,
            .outer_angle = outer_angle,
            .radius = radius,
        } };
    }
};

pub const LightType = enum(u2) {
    directional = 0,
    point = 1,
    spot = 2,
};

pub const MAX_LIGHTS: usize = 8;

pub const PackedLight = struct {
    position: math.Vec3,
    direction: math.Vec3,
    color: math.Vec3,
    intensity: f32,
    light_type: f32,
    params: math.Vec2,

    pub fn fromDirectional(light: DirectionalLight) PackedLight {
        return .{
            .position = .{ .x = 0, .y = 0, .z = 0 },
            .direction = light.direction,
            .color = light.color,
            .intensity = light.intensity,
            .light_type = @as(f32, @intFromEnum(LightType.directional)),
            .params = .{ .x = 0, .y = 0 },
        };
    }

    pub fn fromPoint(light: PointLight) PackedLight {
        return .{
            .position = light.position,
            .direction = .{ .x = 0, .y = 0, .z = 0 },
            .color = light.color,
            .intensity = light.intensity,
            .light_type = @as(f32, @intFromEnum(LightType.point)),
            .params = .{ .x = light.radius, .y = 0 },
        };
    }

    pub fn fromSpot(light: SpotLight) PackedLight {
        const inner_rad = light.inner_angle * std.math.pi / 180.0;
        const outer_rad = light.outer_angle * std.math.pi / 180.0;
        return .{
            .position = light.position,
            .direction = light.direction,
            .color = light.color,
            .intensity = light.intensity,
            .light_type = @as(f32, @intFromEnum(LightType.spot)),
            .params = .{
                .x = light.radius,
                .y = @cos(inner_rad) - @cos(outer_rad),
            },
        };
    }

    pub fn fromUnion(light: Light) PackedLight {
        return switch (light) {
            .dir => |l| PackedLight.fromDirectional(l),
            .pt => |l| PackedLight.fromPoint(l),
            .spotlight => |l| PackedLight.fromSpot(l),
        };
    }
};
