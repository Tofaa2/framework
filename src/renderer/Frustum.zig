const Frustum = @This();
const math = @import("math.zig");

planes: [6][4]f32, // ax + by + cz + d = 0

pub fn fromViewProj(vp: math.Mat) Frustum {
    var f: Frustum = undefined;
    const m = math.matToArr(vp);
    // left
    f.planes[0] = .{ m[3] + m[0], m[7] + m[4], m[11] + m[8], m[15] + m[12] };
    // right
    f.planes[1] = .{ m[3] - m[0], m[7] - m[4], m[11] - m[8], m[15] - m[12] };
    // bottom
    f.planes[2] = .{ m[3] + m[1], m[7] + m[5], m[11] + m[9], m[15] + m[13] };
    // top
    f.planes[3] = .{ m[3] - m[1], m[7] - m[5], m[11] - m[9], m[15] - m[13] };
    // near
    f.planes[4] = .{ m[3] + m[2], m[7] + m[6], m[11] + m[10], m[15] + m[14] };
    // far
    f.planes[5] = .{ m[3] - m[2], m[7] - m[6], m[11] - m[10], m[15] - m[14] };
    // normalize planes
    for (&f.planes) |*plane| {
        const len = @sqrt(plane[0] * plane[0] + plane[1] * plane[1] + plane[2] * plane[2]);
        plane[0] /= len;
        plane[1] /= len;
        plane[2] /= len;
        plane[3] /= len;
    }
    return f;
}

pub fn containsSphere(self: *const Frustum, cx: f32, cy: f32, cz: f32, radius: f32) bool {
    for (self.planes) |plane| {
        const dist = plane[0] * cx + plane[1] * cy + plane[2] * cz + plane[3];
        if (dist < -radius) return false;
    }
    return true;
}
