pub const vec = @import("vec.zig");
pub const mat = @import("mat.zig");
pub const shapes = @import("shapes.zig");

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

pub const Mat4 = mat.Mat4;
pub const Mat3 = mat.Mat3;
pub const Mat2 = mat.Mat2;

pub const Rect = shapes.Rect;
pub const RectI = shapes.RectI;
pub const RectU = shapes.RectU;
pub const Sphere = shapes.Sphere;
pub const AABB = shapes.AABB;
pub const Ray = shapes.Ray;
pub const Plane = shapes.Plane;
pub const Frustum = shapes.Frustum;
pub const Capsule = shapes.Capsule;
pub const Triangle = shapes.Triangle;
pub const Line = shapes.Line;

pub const lerp = vec.lerp;
pub const lerpVec3 = vec.lerpVec3;
pub const clamp = vec.clamp;
pub const clampVec3 = vec.clampVec3;
pub const smoothstep = vec.smoothstep;
pub const distance = vec.distance;
pub const distanceSq = vec.distanceSq;
pub const normalize = vec.normalize;
pub const dot = vec.dot;
pub const cross = vec.cross;
pub const reflect = vec.reflect;
pub const refract = vec.refract;
pub const min = vec.min;
pub const max = vec.max;
pub const abs = vec.abs;
pub const floor = vec.floor;
pub const ceil = vec.ceil;
pub const round = vec.round;
pub const sign = vec.sign;
pub const fract = vec.fract;
