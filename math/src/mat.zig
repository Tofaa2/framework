const SimdVec4 = @Vector(4, f32);
const Vec3 = @import("vec.zig").Vec3;
const Vec4 = @import("vec.zig").Vec4;

pub const Mat4 = struct {
    m: [16]f32,

    pub fn identity() Mat4 {
        return .{
            .m = .{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            },
        };
    }

    pub fn zero() Mat4 {
        return .{ .m = .{0} ** 16 };
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: [16]f32 = undefined;
        for (0..4) |row| {
            for (0..4) |col| {
                result[row * 4 + col] =
                    a.m[row * 4 + 0] * b.m[0 * 4 + col] +
                    a.m[row * 4 + 1] * b.m[1 * 4 + col] +
                    a.m[row * 4 + 2] * b.m[2 * 4 + col] +
                    a.m[row * 4 + 3] * b.m[3 * 4 + col];
            }
        }
        return .{ .m = result };
    }

    pub fn mulSimd(a: Mat4, b: Mat4) Mat4 {
        var result: [16]f32 = undefined;

        inline for (0..4) |row| {
            const row_simd = @as(SimdVec4, a.m[row * 4 .. row * 4 + 4].*);
            inline for (0..4) |col| {
                const col_simd = @as(SimdVec4, b.m[col..16 :4].*);
                result[row * 4 + col] = @reduce(.Add, row_simd * col_simd);
            }
        }

        return .{ .m = result };
    }

    pub fn transformVec4(m: Mat4, v: Vec4) Vec4 {
        const simd = v.toSimd();
        var result: [4]f32 = undefined;

        for (0..4) |row| {
            const row_simd = @as(SimdVec4, m.m[row * 4 .. row * 4 + 4].*);
            result[row] = @reduce(.Add, simd * row_simd);
        }

        return Vec4.fromArray(result);
    }

    pub fn transformVec3(m: Mat4, v: Vec3) Vec3 {
        return m.transformVec4(v.toVec4(1.0)).toVec3();
    }

    pub fn transformPoint(m: Mat4, v: Vec3) Vec3 {
        return m.transformVec4(v.toVec4(1.0)).toVec3();
    }

    pub fn transformNormal(m: Mat4, v: Vec3) Vec3 {
        return m.transformVec4(v.toVec4(0.0)).toVec3();
    }

    pub fn translation(x: f32, y: f32, z: f32) Mat4 {
        var m = identity();
        m.m[12] = x;
        m.m[13] = y;
        m.m[14] = z;
        return m;
    }

    pub fn translationFromVec(v: Vec3) Mat4 {
        return translation(v.x, v.y, v.z);
    }

    pub fn scale(x: f32, y: f32, z: f32) Mat4 {
        return .{ .m = .{
            x,   0.0, 0.0, 0.0,
            0.0, y,   0.0, 0.0,
            0.0, 0.0, z,   0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub fn scaleFromVec(v: Vec3) Mat4 {
        return scale(v.x, v.y, v.z);
    }

    pub fn uniformScale(s: f32) Mat4 {
        return scale(s, s, s);
    }

    pub fn rotationX(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            1.0, 0.0, 0.0, 0.0,
            0.0, c,   s,   0.0,
            0.0, -s,  c,   0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub fn rotationY(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            c,   0.0, -s,  0.0,
            0.0, 1.0, 0.0, 0.0,
            s,   0.0, c,   0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub fn rotationZ(angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{ .m = .{
            c,   s,   0.0, 0.0,
            -s,  c,   0.0, 0.0,
            0.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 1.0,
        } };
    }

    pub fn rotationYawPitchRoll(yaw: f32, pitch: f32, roll: f32) Mat4 {
        return Mat4.mul(Mat4.rotationY(yaw), Mat4.mul(Mat4.rotationX(pitch), Mat4.rotationZ(roll)));
    }

    pub fn rotationAxis(axis: Vec3, angle: f32) Mat4 {
        const c = @cos(angle);
        const s = @sin(angle);
        const t = 1.0 - c;
        const x = axis.x;
        const y = axis.y;
        const z = axis.z;

        return .{ .m = .{
            t * x * x + c,     t * x * y + s * z, t * x * z - s * y, 0.0,
            t * x * y - s * z, t * y * y + c,     t * y * z + s * x, 0.0,
            t * x * z + s * y, t * y * z - s * x, t * z * z + c,     0.0,
            0.0,               0.0,               0.0,               1.0,
        } };
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fov = @tan(fov / 2.0);
        return .{ .m = .{
            1.0 / (aspect * tan_half_fov), 0.0,                0.0,                                0.0,
            0.0,                           1.0 / tan_half_fov, 0.0,                                0.0,
            0.0,                           0.0,                -(far + near) / (far - near),       -1.0,
            0.0,                           0.0,                -(2.0 * far * near) / (far - near), 0.0,
        } };
    }

    pub fn perspectiveDirectX(fov: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const y_scale = 1.0 / @tan(fov / 2.0);
        const x_scale = y_scale / aspect;
        const nearmfar = near - far;

        return .{ .m = .{
            x_scale, 0.0,     0.0,                     0.0,
            0.0,     y_scale, 0.0,                     0.0,
            0.0,     0.0,     far / nearmfar,          -1.0,
            0.0,     0.0,     (near * far) / nearmfar, 0.0,
        } };
    }

    pub fn orthographic(width: f32, height: f32, near: f32, far: f32) Mat4 {
        return .{ .m = .{
            2.0 / width, 0.0,          0.0,                          0.0,
            0.0,         2.0 / height, 0.0,                          0.0,
            0.0,         0.0,          -2.0 / (far - near),          0.0,
            0.0,         0.0,          -(far + near) / (far - near), 1.0,
        } };
    }

    pub fn orthographicOffCenter(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        return .{ .m = .{
            2.0 / (right - left),             0.0,                              0.0,                          0.0,
            0.0,                              2.0 / (top - bottom),             0.0,                          0.0,
            0.0,                              0.0,                              -2.0 / (far - near),          0.0,
            -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0,
        } };
    }

    pub fn lookAtRh(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const z_axis = Vec3.normalize(Vec3.sub(eye, target));
        const x_axis = Vec3.normalize(Vec3.cross(up, z_axis));
        const y_axis = Vec3.cross(z_axis, x_axis);

        return .{ .m = .{
            x_axis.x,               y_axis.x,               z_axis.x,               0.0,
            x_axis.y,               y_axis.y,               z_axis.y,               0.0,
            x_axis.z,               y_axis.z,               z_axis.z,               0.0,
            -Vec3.dot(x_axis, eye), -Vec3.dot(y_axis, eye), -Vec3.dot(z_axis, eye), 1.0,
        } };
    }

    pub fn lookAtLh(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const z_axis = Vec3.normalize(Vec3.sub(target, eye));
        const x_axis = Vec3.normalize(Vec3.cross(up, z_axis));
        const y_axis = Vec3.cross(z_axis, x_axis);

        return .{ .m = .{
            x_axis.x,               y_axis.x,               z_axis.x,               0.0,
            x_axis.y,               y_axis.y,               z_axis.y,               0.0,
            x_axis.z,               y_axis.z,               z_axis.z,               0.0,
            -Vec3.dot(x_axis, eye), -Vec3.dot(y_axis, eye), -Vec3.dot(z_axis, eye), 1.0,
        } };
    }

    pub fn determinant(self: *const Mat4) f32 {
        const m = self.m;
        const a2323 = m[10] * m[15] - m[11] * m[14];
        const a1323 = m[9] * m[15] - m[11] * m[13];
        const a1223 = m[9] * m[14] - m[10] * m[13];
        const a0323 = m[8] * m[15] - m[11] * m[12];
        const a0223 = m[8] * m[14] - m[10] * m[12];
        const a0123 = m[8] * m[13] - m[9] * m[12];
        return m[0] * (m[5] * a2323 - m[6] * a1323 + m[7] * a1223) -
            m[1] * (m[4] * a2323 - m[6] * a0323 + m[7] * a0223) +
            m[2] * (m[4] * a1323 - m[5] * a0323 + m[7] * a0123) -
            m[3] * (m[4] * a1223 - m[5] * a0223 + m[6] * a0123);
    }

    pub fn inverse(self: *const Mat4) Mat4 {
        const m = self.m;

        var inv: [16]f32 = undefined;

        inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
        inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
        inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
        inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
        inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
        inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
        inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
        inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
        inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
        inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
        inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
        inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
        inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
        inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
        inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
        inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];

        var det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];
        if (det == 0.0) return identity();
        det = 1.0 / det;

        for (0..16) |i| {
            inv[i] *= det;
        }

        return .{ .m = inv };
    }

    pub fn transpose(self: *const Mat4) Mat4 {
        const m = self.m;
        return .{ .m = .{
            m[0], m[4], m[8],  m[12],
            m[1], m[5], m[9],  m[13],
            m[2], m[6], m[10], m[14],
            m[3], m[7], m[11], m[15],
        } };
    }

    pub fn toArray(self: *const Mat4) [16]f32 {
        return self.m;
    }

    pub fn fromArray(arr: [16]f32) Mat4 {
        return .{ .m = arr };
    }

    pub fn getTranslation(self: *const Mat4) Vec3 {
        return .{ .x = self.m[12], .y = self.m[13], .z = self.m[14] };
    }

    pub fn getRotation(self: *const Mat4) Mat4 {
        const s = self.getScale();
        var result = self.*;
        result.m[0] /= s.x;
        result.m[1] /= s.x;
        result.m[2] /= s.x;
        result.m[4] /= s.y;
        result.m[5] /= s.y;
        result.m[6] /= s.y;
        result.m[8] /= s.z;
        result.m[9] /= s.z;
        result.m[10] /= s.z;
        return result;
    }

    pub fn getScale(self: *const Mat4) Vec3 {
        return .{
            .x = @sqrt(self.m[0] * self.m[0] + self.m[1] * self.m[1] + self.m[2] * self.m[2]),
            .y = @sqrt(self.m[4] * self.m[4] + self.m[5] * self.m[5] + self.m[6] * self.m[6]),
            .z = @sqrt(self.m[8] * self.m[8] + self.m[9] * self.m[9] + self.m[10] * self.m[10]),
        };
    }
};

pub const Mat3 = struct {
    m: [9]f32,

    pub fn identity() Mat3 {
        return .{
            .m = .{
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
            },
        };
    }

    pub fn fromMat4(m: Mat4) Mat3 {
        return .{
            .m = .{
                m.m[0], m.m[1], m.m[2],
                m.m[4], m.m[5], m.m[6],
                m.m[8], m.m[9], m.m[10],
            },
        };
    }

    pub fn toMat4(self: *const Mat3) Mat4 {
        var result = Mat4.identity();
        result.m[0] = self.m[0];
        result.m[1] = self.m[1];
        result.m[2] = self.m[2];
        result.m[4] = self.m[3];
        result.m[5] = self.m[4];
        result.m[6] = self.m[5];
        result.m[8] = self.m[6];
        result.m[9] = self.m[7];
        result.m[10] = self.m[8];
        return result;
    }

    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: [9]f32 = undefined;
        for (0..3) |row| {
            for (0..3) |col| {
                result[row * 3 + col] =
                    a.m[row * 3 + 0] * b.m[0 * 3 + col] +
                    a.m[row * 3 + 1] * b.m[1 * 3 + col] +
                    a.m[row * 3 + 2] * b.m[2 * 3 + col];
            }
        }
        return .{ .m = result };
    }

    pub fn transformVec3(m: Mat3, v: Vec3) Vec3 {
        return .{
            .x = m.m[0] * v.x + m.m[3] * v.y + m.m[6] * v.z,
            .y = m.m[1] * v.x + m.m[4] * v.y + m.m[7] * v.z,
            .z = m.m[2] * v.x + m.m[5] * v.y + m.m[8] * v.z,
        };
    }
};

pub const Mat2 = struct {
    m: [4]f32,

    pub fn identity() Mat2 {
        return .{
            .m = .{
                1.0, 0.0,
                0.0, 1.0,
            },
        };
    }

    pub fn mul(a: Mat2, b: Mat2) Mat2 {
        var result: [4]f32 = undefined;
        for (0..2) |row| {
            for (0..2) |col| {
                result[row * 2 + col] =
                    a.m[row * 2 + 0] * b.m[0 * 2 + col] +
                    a.m[row * 2 + 1] * b.m[1 * 2 + col];
            }
        }
        return .{ .m = result };
    }

    pub fn transformVec2(m: Mat2, v: Vec3) Vec3 {
        return .{
            .x = m.m[0] * v.x + m.m[2] * v.y,
            .y = m.m[1] * v.x + m.m[3] * v.y,
        };
    }
};
