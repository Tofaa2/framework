const math = @import("../renderer/math.zig");
const zm = math;
const Camera3D = @This();
const std = @import("std");

position: zm.Vec = zm.f32x4(0.0, 0.0, -10.0, 1.0),
target: zm.Vec = zm.f32x4(0.0, 0.0, 0.0, 1.0),
up: zm.Vec = zm.f32x4(0.0, 1.0, 0.0, 0.0),
speed: f32 = 5.0,
yaw: f32 = -std.math.pi / 2.0, // facing -Z by default
pitch: f32 = 0.0,
sensitivity: f32 = 0.002,
pitch_clamp: f32 = std.math.pi / 2.0 - 0.01, // prevent gimbal lock
fov: f32 = std.math.pi / 2.0, // 90 degrees

pub fn init() Camera3D {
    var cam = Camera3D{
        .position = zm.f32x4(0.0, 0.0, -10.0, 1.0),
        .up = zm.f32x4(0.0, 1.0, 0.0, 0.0),
        .speed = 5.0,
        .yaw = std.math.pi / 2.0,
        .pitch = 0.0,
        .sensitivity = 0.002,
        .pitch_clamp = std.math.pi / 2.0 - 0.01,
        .target = zm.f32x4(0.0, 0.0, 0.0, 1.0),
    };
    // sync target with yaw/pitch
    cam.rotate(0, 0);
    return cam;
}

pub fn forwardDir(self: *const Camera3D) zm.Vec {
    return zm.normalize3(self.target - self.position);
}

pub fn rightDir(self: *const Camera3D) zm.Vec {
    return zm.normalize3(zm.cross3(self.forwardDir(), self.up));
}

pub fn rotate(self: *Camera3D, dx: f32, dy: f32) void {
    self.yaw += dx * self.sensitivity;
    self.pitch -= dy * self.sensitivity;
    self.pitch = std.math.clamp(self.pitch, -self.pitch_clamp, self.pitch_clamp);
    // recompute target from yaw/pitch relative to current position
    const forward = zm.f32x4(
        @cos(self.pitch) * @cos(self.yaw),
        @sin(self.pitch),
        @cos(self.pitch) * @sin(self.yaw),
        0.0,
    );
    self.target = self.position + forward;
}

pub fn moveForward(self: *Camera3D, dt: f32) void {
    const delta = self.forwardDir() * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveBackward(self: *Camera3D, dt: f32) void {
    const delta = self.forwardDir() * zm.splat(zm.Vec, self.speed * dt);
    self.position -= delta;
    self.target -= delta;
}

pub fn moveLeft(self: *Camera3D, dt: f32) void {
    const delta = self.rightDir() * zm.splat(zm.Vec, self.speed * dt);
    self.position -= delta;
    self.target -= delta;
}

pub fn moveRight(self: *Camera3D, dt: f32) void {
    const delta = self.rightDir() * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveUp(self: *Camera3D, dt: f32) void {
    const delta = self.up * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveDown(self: *Camera3D, dt: f32) void {
    const delta = self.up * zm.splat(zm.Vec, self.speed * dt);
    self.position -= delta;
    self.target -= delta;
}

pub fn getViewMatrix(self: *const Camera3D) zm.Mat {
    return zm.lookAtRh(self.position, self.target, self.up);
}

pub fn getProjectionMatrix(self: *const Camera3D, width: u32, height: u32) zm.Mat {
    return zm.perspectiveFovRhGl(
        self.fov,
        @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)),
        0.1,
        100.0,
    );
}
