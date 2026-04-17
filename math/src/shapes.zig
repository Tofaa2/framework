const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;
const Vec3 = @import("vec.zig").Vec3;
const Vec4 = @import("vec.zig").Vec4;
const Mat4 = @import("mat.zig").Mat4;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn new(x: f32, y: f32, width: f32, height: f32) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn fromMinMax(a_min: Vec2, a_max: Vec2) Rect {
        return .{
            .x = a_min.x,
            .y = a_min.y,
            .width = a_max.x - a_min.x,
            .height = a_max.y - a_min.y,
        };
    }

    pub fn minP(self: *const Rect) Vec2 {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn maxP(self: *const Rect) Vec2 {
        return .{ .x = self.x + self.width, .y = self.y + self.height };
    }

    pub fn center(self: *const Rect) Vec2 {
        return .{ .x = self.x + self.width * 0.5, .y = self.y + self.height * 0.5 };
    }

    pub fn containsPoint(self: *const Rect, p: Vec2) bool {
        return p.x >= self.x and p.x <= self.x + self.width and
            p.y >= self.y and p.y <= self.y + self.height;
    }

    pub fn intersects(self: *const Rect, other: Rect) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn intersection(self: *const Rect, other: Rect) Rect {
        const x1 = @max(self.x, other.x);
        const y1 = @max(self.y, other.y);
        const x2 = @min(self.x + self.width, other.x + other.width);
        const y2 = @min(self.y + self.height, other.y + other.height);
        return .{
            .x = x1,
            .y = y1,
            .width = @max(0, x2 - x1),
            .height = @max(0, y2 - y1),
        };
    }

    pub fn unionRect(self: *const Rect, other: Rect) Rect {
        const x1 = @min(self.x, other.x);
        const y1 = @min(self.y, other.y);
        const x2 = @max(self.x + self.width, other.x + other.width);
        const y2 = @max(self.y + other.height, other.y + other.height);
        return .{
            .x = x1,
            .y = y1,
            .width = x2 - x1,
            .height = y2 - y1,
        };
    }
};

pub const RectI = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const RectU = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const Sphere = struct {
    center: Vec3,
    radius: f32,

    pub fn new(center: Vec3, radius: f32) Sphere {
        return .{ .center = center, .radius = radius };
    }

    pub fn containsPoint(self: *const Sphere, p: Vec3) bool {
        return Vec3.distance(self.center, p) <= self.radius;
    }

    pub fn intersectsSphere(self: *const Sphere, other: Sphere) bool {
        const dist = Vec3.distance(self.center, other.center);
        return dist <= self.radius + other.radius;
    }

    pub fn intersectsAABB(self: *const Sphere, aabb: AABB) bool {
        const closest = aabb.closestPoint(self.center);
        const dist = Vec3.distance(self.center, closest);
        return dist <= self.radius;
    }
};

pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    pub fn new(a_min: Vec3, a_max: Vec3) AABB {
        return .{ .min = a_min, .max = a_max };
    }

    pub fn fromCenterSize(center_point: Vec3, a_size: Vec3) AABB {
        const half = Vec3.scale(a_size, 0.5);
        return .{
            .min = Vec3.sub(center_point, half),
            .max = Vec3.add(center_point, half),
        };
    }

    pub fn getCenter(self: *const AABB) Vec3 {
        return Vec3.lerp(self.min, self.max, 0.5);
    }

    pub fn fromPositionRadius(pos: Vec3, radius: f32) AABB {
        const r = Vec3.splat(radius);
        return .{ .min = Vec3.sub(pos, r), .max = Vec3.add(pos, r) };
    }

    pub fn center(self: *const AABB) Vec3 {
        return Vec3.lerp(self.min, self.max, 0.5);
    }

    pub fn size(self: *const AABB) Vec3 {
        return Vec3.sub(self.max, self.min);
    }

    pub fn containsPoint(self: *const AABB, p: Vec3) bool {
        return p.x >= self.min.x and p.x <= self.max.x and
            p.y >= self.min.y and p.y <= self.max.y and
            p.z >= self.min.z and p.z <= self.max.z;
    }

    pub fn intersects(self: *const AABB, other: AABB) bool {
        return self.min.x <= other.max.x and self.max.x >= other.min.x and
            self.min.y <= other.max.y and self.max.y >= other.min.y and
            self.min.z <= other.max.z and self.max.z >= other.min.z;
    }

    pub fn closestPoint(self: *const AABB, p: Vec3) Vec3 {
        return .{
            .x = @max(self.min.x, @min(p.x, self.max.x)),
            .y = @max(self.min.y, @min(p.y, self.max.y)),
            .z = @max(self.min.z, @min(p.z, self.max.z)),
        };
    }

    pub fn merge(self: *const AABB, other: AABB) AABB {
        return .{
            .min = Vec3.minVec(self.min, other.min),
            .max = Vec3.maxVec(self.max, other.max),
        };
    }

    pub fn expand(self: *const AABB, amount: f32) AABB {
        const v = Vec3.splat(amount);
        return .{
            .min = Vec3.sub(self.min, v),
            .max = Vec3.add(self.max, v),
        };
    }

    pub fn transform(self: *const AABB, m: Mat4) AABB {
        const corners = self.getCorners();
        var min = m.transformPoint(corners[0]);
        var max = min;

        inline for (1..8) |i| {
            const p = m.transformPoint(corners[i]);
            min = Vec3.minVec(min, p);
            max = Vec3.maxVec(max, p);
        }

        return .{ .min = min, .max = max };
    }

    pub fn getCorners(self: *const AABB) [8]Vec3 {
        return .{
            Vec3.new(self.min.x, self.min.y, self.min.z),
            Vec3.new(self.max.x, self.min.y, self.min.z),
            Vec3.new(self.min.x, self.max.y, self.min.z),
            Vec3.new(self.max.x, self.max.y, self.min.z),
            Vec3.new(self.min.x, self.min.y, self.max.z),
            Vec3.new(self.max.x, self.min.y, self.max.z),
            Vec3.new(self.min.x, self.max.y, self.max.z),
            Vec3.new(self.max.x, self.max.y, self.max.z),
        };
    }
};

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn new(origin: Vec3, direction: Vec3) Ray {
        return .{ .origin = origin, .direction = direction.normalize() };
    }

    pub fn fromTo(from: Vec3, to: Vec3) Ray {
        return .{ .origin = from, .direction = Vec3.normalize(Vec3.sub(to, from)) };
    }

    pub fn at(self: *const Ray, t: f32) Vec3 {
        return Vec3.add(self.origin, Vec3.scale(self.direction, t));
    }

    pub fn intersectsSphere(self: *const Ray, sphere: Sphere) ?f32 {
        const oc = Vec3.sub(self.origin, sphere.center);
        const a = Vec3.dot(self.direction, self.direction);
        const b = 2.0 * Vec3.dot(oc, self.direction);
        const c = Vec3.dot(oc, oc) - sphere.radius * sphere.radius;
        const discriminant = b * b - 4 * a * c;

        if (discriminant < 0) return null;
        const t1 = (-b - @sqrt(discriminant)) / (2.0 * a);
        const t2 = (-b + @sqrt(discriminant)) / (2.0 * a);
        if (t1 > 0) return t1;
        if (t2 > 0) return t2;
        return null;
    }

    pub fn intersectsAABB(self: *const Ray, aabb: AABB) ?f32 {
        var tmin: f32 = -std.math.inf_f32;
        var tmax: f32 = std.math.inf_f32;

        const axes = [3]usize{ 0, 1, 2 };
        inline for (axes) |i| {
            if (@abs(self.direction.toArray()[i]) < 0.0001) {
                if (self.origin.toArray()[i] < aabb.min.toArray()[i] or self.origin.toArray()[i] > aabb.max.toArray()[i]) {
                    return null;
                }
            } else {
                const t1 = (aabb.min.toArray()[i] - self.origin.toArray()[i]) / self.direction.toArray()[i];
                const t2 = (aabb.max.toArray()[i] - self.origin.toArray()[i]) / self.direction.toArray()[i];
                tmin = @max(tmin, @min(t1, t2));
                tmax = @min(tmax, @max(t1, t2));
            }
        }

        if (tmin > tmax or tmax < 0) return null;
        if (tmin < 0) return tmax;
        return tmin;
    }

    pub fn intersectsPlane(self: *const Ray, plane: Plane) ?f32 {
        const denom = Vec3.dot(plane.normal, self.direction);
        if (@abs(denom) < 0.0001) return null;
        const t = (plane.distance - Vec3.dot(plane.normal, self.origin)) / denom;
        if (t < 0) return null;
        return t;
    }
};

pub const Plane = struct {
    normal: Vec3,
    distance: f32,

    pub fn new(normal: Vec3, distance: f32) Plane {
        return .{ .normal = normal.normalize(), .distance = distance };
    }

    pub fn fromPointNormal(point: Vec3, normal: Vec3) Plane {
        return .{ .normal = normal.normalize(), .distance = Vec3.dot(normal, point) };
    }

    pub fn fromPoints(a: Vec3, b: Vec3, c: Vec3) Plane {
        const normal = Vec3.normalize(Vec3.cross(Vec3.sub(b, a), Vec3.sub(c, a)));
        return .{ .normal = normal, .distance = Vec3.dot(normal, a) };
    }

    pub fn distanceToPoint(self: *const Plane, p: Vec3) f32 {
        return Vec3.dot(self.normal, p) - self.distance;
    }

    pub fn closestPoint(self: *const Plane, p: Vec3) Vec3 {
        return Vec3.sub(p, Vec3.scale(self.normal, self.distanceToPoint(p)));
    }
};

pub const Frustum = struct {
    planes: [6]Plane,

    pub fn fromMatrices(view: Mat4, proj: Mat4) Frustum {
        const vp = Mat4.mul(proj, view);

        return .{
            .planes = .{
                Plane.new(Vec3.new(vp.m[3] + vp.m[0], vp.m[7] + vp.m[4], vp.m[11] + vp.m[8]), vp.m[15] + vp.m[12]),
                Plane.new(Vec3.new(vp.m[3] - vp.m[0], vp.m[7] - vp.m[4], vp.m[11] - vp.m[8]), vp.m[15] - vp.m[12]),
                Plane.new(Vec3.new(vp.m[3] + vp.m[1], vp.m[7] + vp.m[5], vp.m[11] + vp.m[9]), vp.m[15] + vp.m[13]),
                Plane.new(Vec3.new(vp.m[3] - vp.m[1], vp.m[7] - vp.m[5], vp.m[11] - vp.m[9]), vp.m[15] - vp.m[13]),
                Plane.new(Vec3.new(vp.m[3] + vp.m[2], vp.m[7] + vp.m[6], vp.m[11] + vp.m[10]), vp.m[15] + vp.m[14]),
                Plane.new(Vec3.new(vp.m[3] - vp.m[2], vp.m[7] - vp.m[6], vp.m[11] - vp.m[10]), vp.m[15] - vp.m[14]),
            },
        };
    }

    pub fn containsPoint(self: *const Frustum, p: Vec3) bool {
        for (self.planes) |plane| {
            if (plane.distanceToPoint(p) < 0) return false;
        }
        return true;
    }

    pub fn intersectsSphere(self: *const Frustum, sphere: Sphere) bool {
        for (self.planes) |plane| {
            if (plane.distanceToPoint(sphere.center) < -sphere.radius) return false;
        }
        return true;
    }

    pub fn intersectsAABB(self: *const Frustum, aabb: AABB) bool {
        for (self.planes) |plane| {
            const p = aabb.closestPoint(Vec3.scale(plane.normal, plane.distance));
            if (plane.distanceToPoint(p) < 0) return false;
        }
        return true;
    }

    pub fn intersectsRay(self: *const Frustum, ray: Ray) bool {
        for (self.planes) |plane| {
            if (ray.intersectsPlane(plane)) |_| {
                return true;
            }
        }
        return false;
    }
};

pub const Capsule = struct {
    start: Vec3,
    end: Vec3,
    radius: f32,

    pub fn new(start: Vec3, end: Vec3, radius: f32) Capsule {
        return .{ .start = start, .end = end, .radius = radius };
    }

    pub fn center(self: *const Capsule) Vec3 {
        return Vec3.lerp(self.start, self.end, 0.5);
    }

    pub fn height(self: *const Capsule) f32 {
        return Vec3.distance(self.start, self.end);
    }
};

pub const Triangle = struct {
    a: Vec3,
    b: Vec3,
    c: Vec3,

    pub fn new(a: Vec3, b: Vec3, c: Vec3) Triangle {
        return .{ .a = a, .b = b, .c = c };
    }

    pub fn normal(self: *const Triangle) Vec3 {
        return Vec3.normalize(Vec3.cross(Vec3.sub(self.b, self.a), Vec3.sub(self.c, self.a)));
    }

    pub fn area(self: *const Triangle) f32 {
        return Vec3.length(Vec3.cross(Vec3.sub(self.b, self.a), Vec3.sub(self.c, self.a))) * 0.5;
    }

    pub fn containsPoint(self: *const Triangle, p: Vec3) bool {
        const v0 = Vec3.sub(self.c, self.a);
        const v1 = Vec3.sub(self.b, self.a);
        const v2 = Vec3.sub(p, self.a);

        const dot00 = Vec3.dot(v0, v0);
        const dot01 = Vec3.dot(v0, v1);
        const dot02 = Vec3.dot(v0, v2);
        const dot11 = Vec3.dot(v1, v1);
        const dot12 = Vec3.dot(v1, v2);

        const inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01);
        const u = (dot11 * dot02 - dot01 * dot12) * inv_denom;
        const v = (dot00 * dot12 - dot01 * dot02) * inv_denom;

        return u >= 0 and v >= 0 and u + v < 1;
    }
};

pub const Line = struct {
    start: Vec3,
    end: Vec3,

    pub fn new(start: Vec3, end: Vec3) Line {
        return .{ .start = start, .end = end };
    }

    pub fn direction(self: *const Line) Vec3 {
        return Vec3.normalize(Vec3.sub(self.end, self.start));
    }

    pub fn length(self: *const Line) f32 {
        return Vec3.distance(self.start, self.end);
    }

    pub fn closestPoint(self: *const Line, p: Vec3) Vec3 {
        const len = self.length();
        const t = @max(0.0, @min(1.0, Vec3.dot(Vec3.sub(p, self.start), Vec3.sub(self.end, self.start)) / (len * len)));
        return Vec3.add(self.start, Vec3.scale(Vec3.sub(self.end, self.start), t));
    }

    pub fn distanceToPoint(self: *const Line, p: Vec3) f32 {
        return Vec3.distance(p, self.closestPoint(p));
    }

    pub fn intersects(self: *const Line, other: *const Line) bool {
        const p = self.closestPoint(other.start);
        return Vec3.distance(p, other.start) <= other.length();
    }
};
