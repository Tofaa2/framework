const std = @import("std");
const SimdVec4 = @Vector(4, f32);

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn splat(v: f32) Vec2 {
        return .{ .x = v, .y = v };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ .x = v.x * s, .y = v.y * s };
    }

    pub fn dot(a: Vec2, b: Vec2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn lengthSq(self: Vec2) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.lengthSq());
    }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len < 0.0001) return Vec2.splat(0);
        return self.scale(1.0 / len);
    }

    pub fn lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
        return Vec2.add(a, Vec2.scale(Vec2.sub(b, a), t));
    }

    pub fn toArray(self: Vec2) [2]f32 {
        return .{ self.x, self.y };
    }

    pub fn fromArray(arr: [2]f32) Vec2 {
        return .{ .x = arr[0], .y = arr[1] };
    }

    pub fn toSimd(self: Vec2) SimdVec4 {
        return @Vector(4, f32){ self.x, self.y, 0.0, 0.0 };
    }

    pub fn fromSimd(v: SimdVec4) Vec2 {
        return .{ .x = v[0], .y = v[1] };
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn one() Vec3 {
        return .{ .x = 1, .y = 1, .z = 1 };
    }

    pub fn up() Vec3 {
        return .{ .x = 0, .y = 1, .z = 0 };
    }

    pub fn down() Vec3 {
        return .{ .x = 0, .y = -1, .z = 0 };
    }

    pub fn forward() Vec3 {
        return .{ .x = 0, .y = 0, .z = -1 };
    }

    pub fn backward() Vec3 {
        return .{ .x = 0, .y = 0, .z = 1 };
    }

    pub fn right() Vec3 {
        return .{ .x = 1, .y = 0, .z = 0 };
    }

    pub fn left() Vec3 {
        return .{ .x = -1, .y = 0, .z = 0 };
    }

    pub fn splat(v: f32) Vec3 {
        return .{ .x = v, .y = v, .z = v };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn mul(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
    }

    pub fn div(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x / b.x, .y = a.y / b.y, .z = a.z / b.z };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn lengthSq(self: Vec3) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.lengthSq());
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len < 0.0001) return Vec3.zero();
        return self.scale(1.0 / len);
    }

    pub fn abs(self: Vec3) Vec3 {
        return .{
            .x = @abs(self.x),
            .y = @abs(self.y),
            .z = @abs(self.z),
        };
    }

    pub fn floor(self: Vec3) Vec3 {
        return .{
            .x = @floor(self.x),
            .y = @floor(self.y),
            .z = @floor(self.z),
        };
    }

    pub fn ceil(self: Vec3) Vec3 {
        return .{
            .x = @ceil(self.x),
            .y = @ceil(self.y),
            .z = @ceil(self.z),
        };
    }

    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return Vec3.add(a, Vec3.scale(Vec3.sub(b, a), t));
    }

    pub fn distance(a: Vec3, b: Vec3) f32 {
        return Vec3.sub(a, b).length();
    }

    pub fn distanceSq(a: Vec3, b: Vec3) f32 {
        return Vec3.sub(a, b).lengthSq();
    }

    pub fn reflect(self: Vec3, normal: Vec3) Vec3 {
        return Vec3.sub(self, Vec3.scale(normal, 2.0 * self.dot(normal)));
    }

    pub fn refract(self: Vec3, normal: Vec3, eta: f32) Vec3 {
        const cos_i = -self.dot(normal);
        const sin2_t = eta * eta * (1.0 - cos_i * cos_i);
        if (sin2_t > 1.0) return Vec3.zero();
        const cos_t = @sqrt(1.0 - sin2_t);
        return Vec3.add(Vec3.scale(self, eta), Vec3.scale(normal, eta * cos_i - cos_t));
    }

    pub fn projectOnto(self: Vec3, onto: Vec3) Vec3 {
        return Vec3.scale(onto, self.dot(onto) / onto.dot(onto));
    }

    pub fn angleTo(self: Vec3, other: Vec3) f32 {
        return std.math.acos(self.normalize().dot(other.normalize()));
    }

    pub fn toArray(self: Vec3) [3]f32 {
        return .{ self.x, self.y, self.z };
    }

    pub fn fromArray(arr: [3]f32) Vec3 {
        return .{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }

    pub fn toVec4(self: Vec3, w: f32) Vec4 {
        return .{ .x = self.x, .y = self.y, .z = self.z, .w = w };
    }

    pub fn fromVec4(v: Vec4) Vec3 {
        return .{ .x = v.x, .y = v.y, .z = v.z };
    }

    pub fn toSimd(self: Vec3) SimdVec4 {
        return @Vector(4, f32){ self.x, self.y, self.z, 0.0 };
    }

    pub fn fromSimd(v: SimdVec4) Vec3 {
        return .{ .x = v[0], .y = v[1], .z = v[2] };
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn zero() Vec4 {
        return .{ .x = 0, .y = 0, .z = 0, .w = 0 };
    }

    pub fn splat(v: f32) Vec4 {
        return .{ .x = v, .y = v, .z = v, .w = v };
    }

    pub fn add(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z, .w = a.w + b.w };
    }

    pub fn sub(a: Vec4, b: Vec4) Vec4 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z, .w = a.w - b.w };
    }

    pub fn scale(v: Vec4, s: f32) Vec4 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s, .w = v.w * s };
    }

    pub fn dot(a: Vec4, b: Vec4) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    }

    pub fn dot3(a: Vec4, b: Vec4) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn lengthSq(self: Vec4) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec4) f32 {
        return @sqrt(self.lengthSq());
    }

    pub fn normalize(self: Vec4) Vec4 {
        const len = self.length();
        if (len < 0.0001) return Vec4.zero();
        return self.scale(1.0 / len);
    }

    pub fn toArray(self: Vec4) [4]f32 {
        return .{ self.x, self.y, self.z, self.w };
    }

    pub fn fromArray(arr: [4]f32) Vec4 {
        return .{ .x = arr[0], .y = arr[1], .z = arr[2], .w = arr[3] };
    }

    pub fn toVec3(self: Vec4) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    pub fn fromVec3(v: Vec3, w: f32) Vec4 {
        return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
    }

    pub fn toSimd(self: Vec4) SimdVec4 {
        return @Vector(4, f32){ self.x, self.y, self.z, self.w };
    }

    pub fn fromSimd(v: SimdVec4) Vec4 {
        return .{ .x = v[0], .y = v[1], .z = v[2], .w = v[3] };
    }
};

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn lerpVec3(a: Vec3, b: Vec3, t: f32) Vec3 {
    return Vec3.lerp(a, b, t);
}

pub fn clamp(value: f32, min_val: f32, max_val: f32) f32 {
    return @max(min_val, @min(max_val, value));
}

pub fn clampVec3(v: Vec3, min_val: Vec3, max_val: Vec3) Vec3 {
    return .{
        .x = clamp(v.x, min_val.x, max_val.x),
        .y = clamp(v.y, min_val.y, max_val.y),
        .z = clamp(v.z, min_val.z, max_val.z),
    };
}

pub fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

pub fn distance(a: Vec3, b: Vec3) f32 {
    return Vec3.distance(a, b);
}

pub fn distanceSq(a: Vec3, b: Vec3) f32 {
    return Vec3.distanceSq(a, b);
}

pub fn normalize(v: Vec3) Vec3 {
    return v.normalize();
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return Vec3.dot(a, b);
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3.cross(a, b);
}

pub fn reflect(normal: Vec3, direction: Vec3) Vec3 {
    return direction.reflect(normal);
}

pub fn refract(direction: Vec3, normal: Vec3, eta: f32) Vec3 {
    return direction.refract(normal, eta);
}

pub fn min(a: f32, b: f32) f32 {
    return @min(a, b);
}

pub fn max(a: f32, b: f32) f32 {
    return @max(a, b);
}

pub fn minVec3(a: Vec3, b: Vec3) Vec3 {
    return .{
        .x = @min(a.x, b.x),
        .y = @min(a.y, b.y),
        .z = @min(a.z, b.z),
    };
}

pub fn maxVec3(a: Vec3, b: Vec3) Vec3 {
    return .{
        .x = @max(a.x, b.x),
        .y = @max(a.y, b.y),
        .z = @max(a.z, b.z),
    };
}

pub fn abs(v: f32) f32 {
    return @abs(v);
}

pub fn floor(v: f32) f32 {
    return @floor(v);
}

pub fn ceil(v: f32) f32 {
    return @ceil(v);
}

pub fn round(v: f32) f32 {
    return @round(v);
}

pub fn sign(v: f32) f32 {
    if (v > 0) return 1.0;
    if (v < 0) return -1.0;
    return 0.0;
}

pub fn fract(v: f32) f32 {
    return v - @floor(v);
}
