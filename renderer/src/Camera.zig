const std = @import("std");
const math = @import("math");
const Camera = @This();

pub const Perspective = struct {
    position: math.Vec3 = math.Vec3.zero(),
    yaw: f32 = 0,
    pitch: f32 = 0,
    fov: f32 = std.math.pi / 3.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,
    aspect: f32 = 16.0 / 9.0,

    pub fn viewMatrix(self: Perspective) math.Mat4 {
        const target = self.getTarget();
        return math.Mat4.lookAtRh(self.position, target, math.Vec3.up());
    }

    pub fn projMatrix(self: Perspective) math.Mat4 {
        return math.Mat4.perspective(self.fov, self.aspect, self.near, self.far);
    }

    pub fn getTarget(self: Perspective) math.Vec3 {
        const cos_pitch = @cos(self.pitch);
        return .{
            .x = self.position.x + cos_pitch * @sin(self.yaw),
            .y = self.position.y - @sin(self.pitch),
            .z = self.position.z + cos_pitch * @cos(self.yaw),
        };
    }

    pub fn getForward(self: Perspective) math.Vec3 {
        const cos_pitch = @cos(self.pitch);
        return .{
            .x = cos_pitch * @sin(self.yaw),
            .y = -@sin(self.pitch),
            .z = cos_pitch * @cos(self.yaw),
        };
    }

    pub fn getRight(self: Perspective) math.Vec3 {
        const fwd = self.getForward();
        return math.Vec3.normalize(math.Vec3.cross(fwd, math.Vec3.up()));
    }

    pub fn addYaw(self: *Perspective, delta: f32) void {
        self.yaw -= delta;
    }

    pub fn addPitch(self: *Perspective, delta: f32) void {
        self.pitch -= delta;
        self.pitch = @max(-std.math.pi / 2.0 + 0.01, @min(std.math.pi / 2.0 - 0.01, self.pitch));
    }

    pub fn lookFromMouse(self: *Perspective, dx: f32, dy: f32, sensitivity: f32) void {
        self.addYaw(dx * sensitivity);
        self.addPitch(-dy * sensitivity);
    }

    pub fn moveForward(self: *Perspective, distance: f32) void {
        const fwd = self.getForward();
        self.position.x += fwd.x * distance;
        self.position.z += fwd.z * distance;
    }

    pub fn moveBackward(self: *Perspective, distance: f32) void {
        self.moveForward(-distance);
    }

    pub fn moveRight(self: *Perspective, distance: f32) void {
        const right = self.getRight();
        self.position.x += right.x * distance;
        self.position.z += right.z * distance;
    }

    pub fn moveLeft(self: *Perspective, distance: f32) void {
        self.moveRight(-distance);
    }

    pub fn moveUp(self: *Perspective, distance: f32) void {
        self.position.y += distance;
    }

    pub fn moveDown(self: *Perspective, distance: f32) void {
        self.moveUp(-distance);
    }

    pub fn setAspect(self: *Perspective, aspect: f32) void {
        self.aspect = aspect;
    }

    pub fn setFromPositionAndTarget(self: *Perspective, pos: math.Vec3, target: math.Vec3) void {
        self.position = pos;
        const dir = math.Vec3.normalize(math.Vec3.sub(target, pos));
        self.yaw = std.math.atan2(dir.x, dir.z);
        self.pitch = std.math.asin(-dir.y);
    }
};

pub const Ortho = struct {
    left: f32 = 0,
    right: f32 = 1280,
    top: f32 = 0,
    bottom: f32 = 720,
    near: f32 = -1,
    far: f32 = 1,
    position: math.Vec3 = math.Vec3.zero(),

    pub fn viewMatrix(_: Ortho) math.Mat4 {
        return math.Mat4.identity();
    }

    pub fn projMatrix(self: Ortho) math.Mat4 {
        return math.Mat4.orthographicOffCenter(self.left, self.right, self.bottom, self.top, self.near, self.far);
    }

    pub fn setSize(self: *Ortho, width: f32, height: f32) void {
        self.right = self.left + width;
        self.bottom = self.top + height;
    }
};

pub const Kind = union(enum) {
    perspective: Perspective,
    ortho: Ortho,
};

kind: Kind,

pub fn perspective(cfg: Perspective) Camera {
    return .{ .kind = .{ .perspective = cfg } };
}

pub fn ortho(cfg: Ortho) Camera {
    return .{ .kind = .{ .ortho = cfg } };
}

pub fn ui(width: f32, height: f32) Camera {
    return ortho(.{
        .left = 0,
        .right = width,
        .top = 0,
        .bottom = height,
        .near = -1,
        .far = 1,
    });
}

pub fn fps(pos: math.Vec3, target: math.Vec3, aspect: f32) Camera {
    var cam: Perspective = .{
        .position = pos,
        .fov = std.math.pi / 3.0,
        .near = 0.1,
        .far = 1000.0,
        .aspect = aspect,
    };
    cam.setFromPositionAndTarget(pos, target);
    return perspective(cam);
}

pub fn viewMatrix(self: Camera) math.Mat4 {
    return switch (self.kind) {
        .perspective => |c| c.viewMatrix(),
        .ortho => |c| c.viewMatrix(),
    };
}

pub fn projMatrix(self: Camera) math.Mat4 {
    return switch (self.kind) {
        .perspective => |c| c.projMatrix(),
        .ortho => |c| c.projMatrix(),
    };
}

pub fn perspectiveRef(self: *Camera) *Perspective {
    return switch (self.kind) {
        .perspective => |*c| c,
        else => unreachable,
    };
}

pub fn position(self: Camera) math.Vec3 {
    return switch (self.kind) {
        .perspective => |c| c.position,
        .ortho => |c| c.position,
    };
}
