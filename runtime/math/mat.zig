const std = @import("std");

const math = @import("root.zig");
const vec = @import("vec.zig");
const quat = @import("quat.zig");

pub fn Mat2x2(
    comptime Scalar: type,
) type {
    return extern struct {
        /// The column vectors of the matrix.
        ///
        /// Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        /// The translation vector is stored in contiguous memory elements 12, 13, 14:
        ///
        /// ```
        /// [4]Vec4{
        ///     vec4( 1,  0,  0,  0),
        ///     vec4( 0,  1,  0,  0),
        ///     vec4( 0,  0,  1,  0),
        ///     vec4(tx, ty, tz, tw),
        /// }
        /// ```
        ///
        /// Use the init() constructor to write code which visually matches the same layout as you'd
        /// see used in scientific / maths communities.
        v: [cols]Vec,

        /// The number of columns, e.g. Mat3x4.cols == 3
        pub const cols = 2;

        /// The number of rows, e.g. Mat3x4.rows == 4
        pub const rows = 2;

        /// The scalar type of this matrix, e.g. Mat3x3.T == f32
        pub const T = Scalar;

        /// The underlying Vec type, e.g. Mat3x3.Vec == Vec3
        pub const Vec = vec.Vec2(Scalar);

        /// The Vec type corresponding to the number of rows, e.g. Mat3x3.RowVec == Vec3
        pub const RowVec = Vec;

        /// The Vec type corresponding to the numebr of cols, e.g. Mat3x4.ColVec = Vec4
        pub const ColVec = Vec;

        const Matrix = @This();

        const Shared = MatShared(RowVec, ColVec, Matrix);

        /// Identity matrix
        pub const ident = Matrix.init(
            &RowVec.init(1, 0),
            &RowVec.init(0, 1),
        );

        /// Constructs a 2x2 matrix with the given rows. For example to write a translation
        /// matrix like in the left part of this equation:
        ///
        /// ```
        /// |1 tx| |x  |   |x+y*tx|
        /// |0 ty| |y=1| = |ty    |
        /// ```
        ///
        /// You would write it with the same visual layout:
        ///
        /// ```
        /// const m = Mat2x2.init(
        ///     vec3(1, tx),
        ///     vec3(0, ty),
        /// );
        /// ```
        ///
        /// Note that Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        pub inline fn init(r0: *const RowVec, r1: *const RowVec) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(r0.x(), r1.x()),
                Vec.init(r0.y(), r1.y()),
            } };
        }

        /// Returns the row `i` of the matrix.
        pub inline fn row(m: *const Matrix, i: usize) RowVec {
            // Note: we inline RowVec.init manually here as it is faster in debug builds.
            // return RowVec.init(m.v[0].v[i], m.v[1].v[i]);
            return .{ .v = .{ m.v[0].v[i], m.v[1].v[i] } };
        }

        /// Returns the column `i` of the matrix.
        pub inline fn col(m: *const Matrix, i: usize) RowVec {
            // Note: we inline RowVec.init manually here as it is faster in debug builds.
            // return RowVec.init(m.v[i].v[0], m.v[i].v[1]);
            return .{ .v = .{ m.v[i].v[0], m.v[i].v[1] } };
        }

        /// Transposes the matrix.
        pub inline fn transpose(m: *const Matrix) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(m.v[0].v[0], m.v[1].v[0]),
                Vec.init(m.v[0].v[1], m.v[1].v[1]),
            } };
        }

        /// Constructs a 1D matrix which scales each dimension by the given scalar.
        pub inline fn scaleScalar(t: Vec.T) Matrix {
            return init(
                &RowVec.init(t, 0),
                &RowVec.init(0, 1),
            );
        }

        /// Constructs a 1D matrix which translates coordinates by the given scalar.
        pub inline fn translateScalar(t: Vec.T) Matrix {
            return init(
                &RowVec.init(1, t),
                &RowVec.init(0, 1),
            );
        }

        pub const mul = Shared.mul;
        pub const mulVec = Shared.mulVec;
        pub const format = Shared.format;
    };
}

pub fn Mat3x3(
    comptime Scalar: type,
) type {
    return extern struct {
        /// The column vectors of the matrix.
        ///
        /// Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        /// The translation vector is stored in contiguous memory elements 12, 13, 14:
        ///
        /// ```
        /// [4]Vec4{
        ///     vec4( 1,  0,  0,  0),
        ///     vec4( 0,  1,  0,  0),
        ///     vec4( 0,  0,  1,  0),
        ///     vec4(tx, ty, tz, tw),
        /// }
        /// ```
        ///
        /// Use the init() constructor to write code which visually matches the same layout as you'd
        /// see used in scientific / maths communities.
        v: [cols]Vec,

        /// The number of columns, e.g. Mat3x4.cols == 3
        pub const cols = 3;

        /// The number of rows, e.g. Mat3x4.rows == 4
        pub const rows = 3;

        /// The scalar type of this matrix, e.g. Mat3x3.T == f32
        pub const T = Scalar;

        /// The underlying Vec type, e.g. Mat3x3.Vec == Vec3
        pub const Vec = vec.Vec3(Scalar);

        /// The Vec type corresponding to the number of rows, e.g. Mat3x3.RowVec == Vec3
        pub const RowVec = Vec;

        /// The Vec type corresponding to the numebr of cols, e.g. Mat3x4.ColVec = Vec4
        pub const ColVec = Vec;

        const Matrix = @This();

        const Shared = MatShared(RowVec, ColVec, Matrix);

        /// Identity matrix
        pub const ident = Matrix.init(
            &RowVec.init(1, 0, 0),
            &RowVec.init(0, 1, 0),
            &RowVec.init(0, 0, 1),
        );

        /// Constructs a 3x3 matrix with the given rows. For example to write a translation
        /// matrix like in the left part of this equation:
        ///
        /// ```
        /// |1 0 tx| |x  |   |x+z*tx|
        /// |0 1 ty| |y  | = |y+z*ty|
        /// |0 0 tz| |z=1|   |tz    |
        /// ```
        ///
        /// You would write it with the same visual layout:
        ///
        /// ```
        /// const m = Mat3x3.init(
        ///     vec3(1, 0, tx),
        ///     vec3(0, 1, ty),
        ///     vec3(0, 0, tz),
        /// );
        /// ```
        ///
        /// Note that Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        pub inline fn init(r0: *const RowVec, r1: *const RowVec, r2: *const RowVec) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(r0.x(), r1.x(), r2.x()),
                Vec.init(r0.y(), r1.y(), r2.y()),
                Vec.init(r0.z(), r1.z(), r2.z()),
            } };
        }

        /// Returns the row `i` of the matrix.
        pub inline fn row(m: *const Matrix, i: usize) RowVec {
            // Note: we inline RowVec.init manually here as it is faster in debug builds.
            // return RowVec.init(m.v[0].v[i], m.v[1].v[i], m.v[2].v[i]);
            return .{ .v = .{ m.v[0].v[i], m.v[1].v[i], m.v[2].v[i] } };
        }

        /// Returns the column `i` of the matrix.
        pub inline fn col(m: *const Matrix, i: usize) RowVec {
            // Note: we inline RowVec.init manually here as it is faster in debug builds.
            // return RowVec.init(m.v[i].v[0], m.v[i].v[1], m.v[i].v[2]);
            return .{ .v = .{ m.v[i].v[0], m.v[i].v[1], m.v[i].v[2] } };
        }

        /// Transposes the matrix.
        pub inline fn transpose(m: *const Matrix) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(m.v[0].v[0], m.v[1].v[0], m.v[2].v[0]),
                Vec.init(m.v[0].v[1], m.v[1].v[1], m.v[2].v[1]),
                Vec.init(m.v[0].v[2], m.v[1].v[2], m.v[2].v[2]),
            } };
        }

        /// Constructs a 2D matrix which scales each dimension by the given vector.
        pub inline fn scale(s: math.Vec2) Matrix {
            return init(
                &RowVec.init(s.x(), 0, 0),
                &RowVec.init(0, s.y(), 0),
                &RowVec.init(0, 0, 1),
            );
        }

        /// Constructs a 2D matrix which scales each dimension by the given scalar.
        pub inline fn scaleScalar(t: Vec.T) Matrix {
            return scale(math.Vec2.splat(t));
        }

        /// Constructs a 2D matrix which translates coordinates by the given vector.
        pub inline fn translate(t: math.Vec2) Matrix {
            return init(
                &RowVec.init(1, 0, t.x()),
                &RowVec.init(0, 1, t.y()),
                &RowVec.init(0, 0, 1),
            );
        }

        /// Constructs a 2D matrix which translates coordinates by the given scalar.
        pub inline fn translateScalar(t: Vec.T) Matrix {
            return translate(math.Vec2.splat(t));
        }

        /// Returns the translation component of the matrix.
        pub inline fn translation(t: Matrix) math.Vec2 {
            return math.Vec2.init(t.v[2].x(), t.v[2].y());
        }

        pub const mul = Shared.mul;
        pub const mulVec = Shared.mulVec;
        pub const format = Shared.format;
    };
}

pub fn Mat4x4(
    comptime Scalar: type,
) type {
    return extern struct {
        /// The column vectors of the matrix.
        ///
        /// Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        /// The translation vector is stored in contiguous memory elements 12, 13, 14:
        ///
        /// ```
        /// [4]Vec4{
        ///     vec4( 1,  0,  0,  0),
        ///     vec4( 0,  1,  0,  0),
        ///     vec4( 0,  0,  1,  0),
        ///     vec4(tx, ty, tz, tw),
        /// }
        /// ```
        ///
        /// Use the init() constructor to write code which visually matches the same layout as you'd
        /// see used in scientific / maths communities.
        v: [cols]Vec,

        /// The number of columns, e.g. Mat3x4.cols == 3
        pub const cols = 4;

        /// The number of rows, e.g. Mat3x4.rows == 4
        pub const rows = 4;

        /// The scalar type of this matrix, e.g. Mat3x3.T == f32
        pub const T = Scalar;

        /// The underlying Vec type, e.g. Mat3x3.Vec == Vec3
        pub const Vec = vec.Vec4(Scalar);

        /// The Vec type corresponding to the number of rows, e.g. Mat3x3.RowVec == Vec3
        pub const RowVec = Vec;

        /// The Vec type corresponding to the numebr of cols, e.g. Mat3x4.ColVec = Vec4
        pub const ColVec = Vec;

        const Matrix = @This();

        const Shared = MatShared(RowVec, ColVec, Matrix);

        /// Identity matrix
        pub const ident = Matrix.init(
            &Vec.init(1, 0, 0, 0),
            &Vec.init(0, 1, 0, 0),
            &Vec.init(0, 0, 1, 0),
            &Vec.init(0, 0, 0, 1),
        );

        /// Constructs a view matrix that transforms world space into camera space.
        /// `eye` is the camera position, `target` is the point to look at, and `up`
        /// is the world up vector (typically vec3(0, 1, 0)).
        pub inline fn lookAt(eye: math.Vec3, target: math.Vec3, up: math.Vec3) Matrix {
            const f = target.sub(&eye).normalize(0); // forward
            const r = f.cross(&up).normalize(0); // right
            const u = r.cross(&f); // up (recomputed)

            return Matrix.init(
                &RowVec.init(r.x(), r.y(), r.z(), -r.dot(&eye)),
                &RowVec.init(u.x(), u.y(), u.z(), -u.dot(&eye)),
                &RowVec.init(-f.x(), -f.y(), -f.z(), f.dot(&eye)),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 4x4 matrix with the given rows. For example to write a translation
        /// matrix like in the left part of this equation:
        ///
        /// ```
        /// |1 0 0 tx| |x  |   |x+w*tx|
        /// |0 1 0 ty| |y  | = |y+w*ty|
        /// |0 0 1 tz| |z  |   |z+w*tz|
        /// |0 0 0 tw| |w=1|   |tw    |
        /// ```
        ///
        /// You would write it with the same visual layout:
        ///
        /// ```
        /// const m = Mat4x4.init(
        ///     &vec4(1, 0, 0, tx),
        ///     &vec4(0, 1, 0, ty),
        ///     &vec4(0, 0, 1, tz),
        ///     &vec4(0, 0, 0, tw),
        /// );
        /// ```
        ///
        /// Note that Mach matrices use [column-major storage and column-vectors](https://machengine.org/engine/math/matrix-storage/).
        pub inline fn init(r0: *const RowVec, r1: *const RowVec, r2: *const RowVec, r3: *const RowVec) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(r0.x(), r1.x(), r2.x(), r3.x()),
                Vec.init(r0.y(), r1.y(), r2.y(), r3.y()),
                Vec.init(r0.z(), r1.z(), r2.z(), r3.z()),
                Vec.init(r0.w(), r1.w(), r2.w(), r3.w()),
            } };
        }

        /// Returns the row `i` of the matrix.
        pub inline fn row(m: *const Matrix, i: usize) RowVec {
            return RowVec{ .v = RowVec.Vector{ m.v[0].v[i], m.v[1].v[i], m.v[2].v[i], m.v[3].v[i] } };
        }

        /// Returns the column `i` of the matrix.
        pub inline fn col(m: *const Matrix, i: usize) RowVec {
            return RowVec{ .v = RowVec.Vector{ m.v[i].v[0], m.v[i].v[1], m.v[i].v[2], m.v[i].v[3] } };
        }

        /// Transposes the matrix.
        pub inline fn transpose(m: *const Matrix) Matrix {
            return .{ .v = [_]Vec{
                Vec.init(m.v[0].v[0], m.v[1].v[0], m.v[2].v[0], m.v[3].v[0]),
                Vec.init(m.v[0].v[1], m.v[1].v[1], m.v[2].v[1], m.v[3].v[1]),
                Vec.init(m.v[0].v[2], m.v[1].v[2], m.v[2].v[2], m.v[3].v[2]),
                Vec.init(m.v[0].v[3], m.v[1].v[3], m.v[2].v[3], m.v[3].v[3]),
            } };
        }

        /// Constructs a 3D matrix which scales each dimension by the given vector.
        pub inline fn scale(s: math.Vec3) Matrix {
            return init(
                &RowVec.init(s.x(), 0, 0, 0),
                &RowVec.init(0, s.y(), 0, 0),
                &RowVec.init(0, 0, s.z(), 0),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 3D matrix which scales each dimension by the given scalar.
        pub inline fn scaleScalar(s: Vec.T) Matrix {
            return scale(math.Vec3.splat(s));
        }

        /// Constructs a 3D matrix which translates coordinates by the given vector.
        pub inline fn translate(t: math.Vec3) Matrix {
            return init(
                &RowVec.init(1, 0, 0, t.x()),
                &RowVec.init(0, 1, 0, t.y()),
                &RowVec.init(0, 0, 1, t.z()),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 3D matrix which translates coordinates by the given scalar.
        pub inline fn translateScalar(t: Vec.T) Matrix {
            return translate(math.Vec3.splat(t));
        }

        /// Returns the translation component of the matrix.
        pub inline fn translation(t: *const Matrix) math.Vec3 {
            return math.Vec3.init(t.v[3].x(), t.v[3].y(), t.v[3].z());
        }

        /// Constructs a 3D matrix which rotates around the X axis by `angle_radians`.
        pub inline fn rotateX(angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            return Matrix.init(
                &RowVec.init(1, 0, 0, 0),
                &RowVec.init(0, c, -s, 0),
                &RowVec.init(0, s, c, 0),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 3D matrix which rotates around the X axis by `angle_radians`.
        pub inline fn rotateY(angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            return Matrix.init(
                &RowVec.init(c, 0, s, 0),
                &RowVec.init(0, 1, 0, 0),
                &RowVec.init(-s, 0, c, 0),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 3D matrix which rotates around the Z axis by `angle_radians`.
        pub inline fn rotateZ(angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            return Matrix.init(
                &RowVec.init(c, -s, 0, 0),
                &RowVec.init(s, c, 0, 0),
                &RowVec.init(0, 0, 1, 0),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        //https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToMatrix/jay.htm
        //Requires a normalized quaternion
        pub inline fn rotateByQuaternion(quaternion: quat.Quat(T)) Matrix {
            const qx = quaternion.v.x();
            const qy = quaternion.v.y();
            const qz = quaternion.v.z();
            const qw = quaternion.v.w();

            return Matrix.init(
                &RowVec.init(1 - 2 * qy * qy - 2 * qz * qz, 2 * qx * qy - 2 * qz * qw, 2 * qx * qz + 2 * qy * qw, 0),
                &RowVec.init(2 * qx * qy + 2 * qz * qw, 1 - 2 * qx * qx - 2 * qz * qz, 2 * qy * qz - 2 * qx * qw, 0),
                &RowVec.init(2 * qx * qz - 2 * qy * qw, 2 * qy * qz + 2 * qx * qw, 1 - 2 * qx * qx - 2 * qy * qy, 0),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        /// Constructs a 2D projection matrix, aka. an orthographic projection matrix.
        ///
        /// First, a cuboid is defined with the parameters:
        ///
        /// * (right - left) defining the distance between the left and right faces of the cube
        /// * (top - bottom) defining the distance between the top and bottom faces of the cube
        /// * (near - far) defining the distance between the back (near) and front (far) faces of the cube
        ///
        /// We then need to construct a projection matrix which converts points in that
        /// cuboid's space into clip space:
        ///
        /// https://machengine.org/engine/math/traversing-coordinate-systems/#view---clip-space
        ///
        /// Normally, in sysgpu/webgpu the depth buffer of floating point values would
        /// have the range [0, 1] representing [near, far], i.e. a pixel very close to the
        /// viewer would have a depth value of 0.0, and a pixel very far from the viewer
        /// would have a depth value of 1.0. But this is an ineffective use of floating
        /// point precision, a better approach is a reversed depth buffer:
        ///
        /// * https://webgpu.github.io/webgpu-samples/samples/reversedZ
        /// * https://developer.nvidia.com/content/depth-precision-visualized
        ///
        /// Mach mandates the use of a reversed depth buffer, so the returned transformation
        /// matrix maps to near=1 and far=0.
        pub inline fn projection2D(v: struct {
            left: f32,
            right: f32,
            bottom: f32,
            top: f32,
            near: f32,
            far: f32,
        }) Matrix {
            var p = Matrix.ident;
            p = p.mul(&Matrix.translate(math.vec3(
                (v.right + v.left) / (v.left - v.right), // translate X so that the middle of (left, right) maps to x=0 in clip space
                (v.top + v.bottom) / (v.bottom - v.top), // translate Y so that the middle of (bottom, top) maps to y=0 in clip space
                v.far / (v.far - v.near), // translate Z so that far maps to z=0
            )));
            p = p.mul(&Matrix.scale(math.vec3(
                2 / (v.right - v.left), // scale X so that [left, right] has a 2 unit range, e.g. [-1, +1]
                2 / (v.top - v.bottom), // scale Y so that [bottom, top] has a 2 unit range, e.g. [-1, +1]
                1 / (v.near - v.far), // scale Z so that [near, far] has a 1 unit range, e.g. [0, -1]
            )));
            return p;
        }

        /// Applies a scale to an existing matrix by the given vector,
        /// equivalent to `glm::scale(m, s)`.
        /// This is equivalent to `m * Mat4x4.scale(s)` but avoids the full matrix multiply
        /// by only scaling the columns directly.
        pub inline fn scaleVec(m: *const Matrix, s: math.Vec3) Matrix {
            return .{ .v = [_]Vec{
                m.v[0].mulScalar(s.x()),
                m.v[1].mulScalar(s.y()),
                m.v[2].mulScalar(s.z()),
                m.v[3],
            } };
        }

        /// Applies a uniform scale to an existing matrix by the given scalar,
        /// equivalent to `glm::scale(m, vec3(s))`.
        pub inline fn scaleVecScalar(m: *const Matrix, s: Vec.T) Matrix {
            return m.scaleVec(math.Vec3.splat(s));
        }

        /// Applies a rotation to an existing matrix by `angle_radians` around the given `axis`,
        /// equivalent to `glm::rotate(m, angle_radians, axis)`.
        /// The axis does not need to be normalized; it will be normalized internally.
        pub inline fn rotateVec(m: *const Matrix, angle_radians: f32, axis: math.Vec3) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            const one_minus_c = 1.0 - c;

            const a = axis.normalize(0);
            const ax = a.x();
            const ay = a.y();
            const az = a.z();

            // Rodrigues' rotation matrix
            const r = Matrix.init(
                &RowVec.init(c + ax * ax * one_minus_c, ax * ay * one_minus_c - az * s, ax * az * one_minus_c + ay * s, 0),
                &RowVec.init(ay * ax * one_minus_c + az * s, c + ay * ay * one_minus_c, ay * az * one_minus_c - ax * s, 0),
                &RowVec.init(az * ax * one_minus_c - ay * s, az * ay * one_minus_c + ax * s, c + az * az * one_minus_c, 0),
                &RowVec.init(0, 0, 0, 1),
            );

            return m.mul(&r);
        }

        /// Applies a rotation to an existing matrix around the X axis by `angle_radians`,
        /// equivalent to `glm::rotate(m, angle_radians, vec3(1, 0, 0))` but cheaper.
        pub inline fn rotateVecX(m: *const Matrix, angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            const r = Matrix.init(
                &RowVec.init(1, 0, 0, 0),
                &RowVec.init(0, c, -s, 0),
                &RowVec.init(0, s, c, 0),
                &RowVec.init(0, 0, 0, 1),
            );
            return m.mul(&r);
        }

        /// Applies a rotation to an existing matrix around the Y axis by `angle_radians`,
        /// equivalent to `glm::rotate(m, angle_radians, vec3(0, 1, 0))` but cheaper.
        pub inline fn rotateVecY(m: *const Matrix, angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            const r = Matrix.init(
                &RowVec.init(c, 0, s, 0),
                &RowVec.init(0, 1, 0, 0),
                &RowVec.init(-s, 0, c, 0),
                &RowVec.init(0, 0, 0, 1),
            );
            return m.mul(&r);
        }

        /// Applies a rotation to an existing matrix around the Z axis by `angle_radians`,
        /// equivalent to `glm::rotate(m, angle_radians, vec3(0, 0, 1))` but cheaper.
        pub inline fn rotateVecZ(m: *const Matrix, angle_radians: f32) Matrix {
            const c = math.cos(angle_radians);
            const s = math.sin(angle_radians);
            const r = Matrix.init(
                &RowVec.init(c, -s, 0, 0),
                &RowVec.init(s, c, 0, 0),
                &RowVec.init(0, 0, 1, 0),
                &RowVec.init(0, 0, 0, 1),
            );
            return m.mul(&r);
        }

        /// Applies a translation to an existing matrix, equivalent to `glm::translate(m, t)`.
        /// This is equivalent to `m * Mat4x4.translate(t)` but avoids the full matrix multiply
        /// by only touching the column that changes.
        pub inline fn translateVec(m: *const Matrix, t: math.Vec3) Matrix {
            // result = m * T, where T is a pure translation matrix.
            // Only the last column differs from m: result.v[3] = m.v[0]*tx + m.v[1]*ty + m.v[2]*tz + m.v[3]
            const tx = m.v[0].mulScalar(t.x());
            const ty = m.v[1].mulScalar(t.y());
            const tz = m.v[2].mulScalar(t.z());
            return .{ .v = [_]Vec{
                m.v[0],
                m.v[1],
                m.v[2],
                Vec.init(
                    tx.x() + ty.x() + tz.x() + m.v[3].x(),
                    tx.y() + ty.y() + tz.y() + m.v[3].y(),
                    tx.z() + ty.z() + tz.z() + m.v[3].z(),
                    tx.w() + ty.w() + tz.w() + m.v[3].w(),
                ),
            } };
        }

        /// Applies a translation to an existing matrix by a scalar, equivalent to
        /// `glm::translate(m, vec3(s))`.
        pub inline fn translateVecScalar(m: *const Matrix, s: Vec.T) Matrix {
            return m.translateVec(math.Vec3.splat(s));
        }

        /// Constructs a perspective projection matrix (right-handed, reversed-Z).
        ///
        /// * `fov_y_radians` is the vertical field of view angle
        /// * `aspect_ratio` is the viewport width divided by height
        /// * `near` is the distance to the near clip plane
        /// * `far` is the distance to the far clip plane (use `std.math.inf(f32)` for an infinite far plane)
        ///
        /// Like projection2D, this uses a reversed depth buffer mapping near=1 and far=0.
        pub inline fn projection(
            fov_y_radians: f32,
            aspect_ratio: f32,
            near: f32,
            far: f32,
        ) Matrix {
            const tan_half_fov = std.math.tan(fov_y_radians / 2.0);
            const a = 1.0 / (aspect_ratio * tan_half_fov);
            const b = 1.0 / tan_half_fov;

            if (std.math.isInf(far)) {
                // Infinite far plane — reversed Z, maps near=1, far=0
                return Matrix.init(
                    &RowVec.init(a, 0, 0, 0),
                    &RowVec.init(0, b, 0, 0),
                    &RowVec.init(0, 0, 0, -1),
                    &RowVec.init(0, 0, near, 0),
                );
            }

            // Finite far plane — reversed Z, maps near=1, far=0
            const range = far / (near - far);
            return Matrix.init(
                &RowVec.init(a, 0, 0, 0),
                &RowVec.init(0, b, 0, 0),
                &RowVec.init(0, 0, range, -1),
                &RowVec.init(0, 0, range * near, 0),
            );
        }

        /// Constructs a 3D orthographic projection matrix (right-handed, reversed-Z).
        ///
        /// Maps the axis-aligned box defined by (left, right, bottom, top, near, far)
        /// into clip space with near=1 and far=0, consistent with projection2D and
        /// Mach's reversed depth buffer convention.
        ///
        /// Unlike projection2D which is intended for 2D screen-space rendering, this
        /// function is suited for 3D scenes where you want parallel projection — e.g.
        /// isometric views, CAD, or shadow map rendering.
        pub inline fn orthographic(v: struct {
            left: f32,
            right: f32,
            bottom: f32,
            top: f32,
            near: f32,
            far: f32,
        }) Matrix {
            const rl = v.right - v.left;
            const tb = v.top - v.bottom;
            const nf = v.near - v.far;

            return Matrix.init(
                &RowVec.init(2.0 / rl, 0, 0, -(v.right + v.left) / rl),
                &RowVec.init(0, 2.0 / tb, 0, -(v.top + v.bottom) / tb),
                &RowVec.init(0, 0, 1.0 / nf, v.far / nf),
                &RowVec.init(0, 0, 0, 1),
            );
        }

        pub const mul = Shared.mul;
        pub const mulVec = Shared.mulVec;
        pub const eql = Shared.eql;
        pub const eqlApprox = Shared.eqlApprox;
        pub const format = Shared.format;
    };
}

pub fn MatShared(comptime RowVec: type, comptime ColVec: type, comptime Matrix: type) type {
    return struct {
        /// Matrix multiplication a*b
        pub inline fn mul(a: *const Matrix, b: *const Matrix) Matrix {
            @setEvalBranchQuota(10000);
            var result: Matrix = undefined;
            inline for (0..Matrix.rows) |row| {
                inline for (0..Matrix.cols) |col| {
                    var sum: RowVec.T = 0.0;
                    inline for (0..RowVec.n) |i| {
                        // Note: we directly access rows/columns below as it is much faster **in
                        // debug builds**, instead of using these helpers:
                        //
                        // sum += a.row(row).mul(&b.col(col)).v[i];
                        sum += a.v[i].v[row] * b.v[col].v[i];
                    }
                    result.v[col].v[row] = sum;
                }
            }
            return result;
        }

        /// Matrix * Vector multiplication
        pub inline fn mulVec(matrix: *const Matrix, vector: *const ColVec) ColVec {
            var result = [_]ColVec.T{0} ** ColVec.n;
            inline for (0..Matrix.rows) |row| {
                inline for (0..ColVec.n) |i| {
                    result[i] += matrix.v[row].v[i] * vector.v[row];
                }
            }
            return ColVec{ .v = result };
        }

        /// Check if two matrices are approximately equal. Returns true if the absolute difference between
        /// each element in matrix is less than or equal to the specified tolerance.
        pub inline fn eqlApprox(a: *const Matrix, b: *const Matrix, tolerance: ColVec.T) bool {
            inline for (0..Matrix.rows) |row| {
                if (!ColVec.eqlApprox(&a.v[row], &b.v[row], tolerance)) {
                    return false;
                }
            }
            return true;
        }

        /// Check if two matrices are approximately equal. Returns true if the absolute difference between
        /// each element in matrix is less than or equal to the epsilon tolerance.
        pub inline fn eql(a: *const Matrix, b: *const Matrix) bool {
            inline for (0..Matrix.rows) |row| {
                if (!ColVec.eql(&a.v[row], &b.v[row])) {
                    return false;
                }
            }
            return true;
        }

        /// Custom format function for all matrix types.
        pub inline fn format(
            self: Matrix,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            const rows = @TypeOf(self).rows;
            try writer.print("{{", .{});
            inline for (0..rows) |r| {
                try std.fmt.formatType(self.row(r), fmt, options, writer, 1);
                if (r < rows - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print("}}", .{});
        }
    };
}
