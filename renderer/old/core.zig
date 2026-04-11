/// Core renderer types and utilities
const std = @import("std");
const bgfx = @import("bgfx").bgfx;

pub const Vertex = extern struct {
    position: [3]f32,
    color: u32,
    uv: [2]f32,
    normal: [3]f32,
    tangent: [4]f32,
};

pub const Vec2 = struct { x: f32, y: f32 };
pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Vec4 = struct { x: f32, y: f32, z: f32, w: f32 };

pub const Mat4 = extern struct {
    data: [16]f32,

    pub fn identity() Mat4 {
        return .{ .data = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = undefined;
        for (0..4) |row| {
            for (0..4) |col| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.data[row * 4 + k] * b.data[k * 4 + col];
                }
                result.data[row * 4 + col] = sum;
            }
        }
        return result;
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fov = @tan(fov / 2);
        var m: Mat4 = undefined;
        @memset(&m.data, 0);
        m.data[0] = 1 / (aspect * tan_half_fov);
        m.data[5] = 1 / tan_half_fov;
        m.data[10] = -(far + near) / (far - near);
        m.data[11] = -1;
        m.data[14] = -(2 * far * near) / (far - near);
        return m;
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = Vec3{
            .x = target.x - eye.x,
            .y = target.y - eye.y,
            .z = target.z - eye.z,
        };
        const flen = @sqrt(f.x * f.x + f.y * f.y + f.z * f.z);
        const fx = f.x / flen;
        const fy = f.y / flen;
        const fz = f.z / flen;

        const r = Vec3{
            .x = up.y * fz - up.z * fy,
            .y = up.z * fx - up.x * fz,
            .z = up.x * fy - up.y * fx,
        };
        const rlen = @sqrt(r.x * r.x + r.y * r.y + r.z * r.z);
        const rx = r.x / rlen;
        const ry = r.y / rlen;
        const rz = r.z / rlen;

        const u = Vec3{
            .x = fy * rz - fz * ry,
            .y = fz * rx - fx * rz,
            .z = fx * ry - fy * rx,
        };

        const m: Mat4 = .{ .data = .{
            rx,                                      u.x,                                        -fx,                                    0,
            ry,                                      u.y,                                        -fy,                                    0,
            rz,                                      u.z,                                        -fz,                                    0,
            -(rx * eye.x + ry * eye.y + rz * eye.z), -(u.x * eye.x + u.y * eye.y + u.z * eye.z), (fx * eye.x + fy * eye.y + fz * eye.z), 1,
        } };
        return m;
    }

    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        return .{ .data = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1,
        } };
    }

    pub fn scaling(x: f32, y: f32, z: f32) Mat4 {
        return .{ .data = .{
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn rotationX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .data = .{
            1, 0,  0, 0,
            0, c,  s, 0,
            0, -s, c, 0,
            0, 0,  0, 1,
        } };
    }

    pub fn rotationY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .data = .{
            c, 0, -s, 0,
            0, 1, 0,  0,
            s, 0, c,  0,
            0, 0, 0,  1,
        } };
    }

    pub fn rotationZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .data = .{
            c,  s, 0, 0,
            -s, c, 0, 0,
            0,  0, 1, 0,
            0,  0, 0, 1,
        } };
    }

    pub fn fromArray(arr: [16]f32) Mat4 {
        return .{ .data = arr };
    }
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1.0 };
    }

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn white() Color {
        return rgb(1, 1, 1);
    }
    pub fn black() Color {
        return rgb(0, 0, 0);
    }
    pub fn red() Color {
        return rgb(1, 0, 0);
    }
    pub fn green() Color {
        return rgb(0, 1, 0);
    }
    pub fn blue() Color {
        return rgb(0, 0, 1);
    }

    pub fn toU32(self: Color) u32 {
        const ri: u8 = @intFromFloat(@min(self.r * 255, 255));
        const gi: u8 = @intFromFloat(@min(self.g * 255, 255));
        const bi: u8 = @intFromFloat(@min(self.b * 255, 255));
        const ai: u8 = @intFromFloat(@min(self.a * 255, 255));
        return @as(u32, ai) << 24 | @as(u32, ri) << 16 | @as(u32, gi) << 8 | bi;
    }
};
