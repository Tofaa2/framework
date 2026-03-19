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
pub fn rotate(self: *Camera3D, dx: f32, dy: f32) void {
    self.yaw += dx * self.sensitivity;
    self.pitch -= dy * self.sensitivity; // subtract because Y is flipped
    self.pitch = std.math.clamp(self.pitch, -self.pitch_clamp, self.pitch_clamp);

    const dir = zm.f32x4(
        @cos(self.pitch) * @cos(self.yaw),
        @sin(self.pitch),
        @cos(self.pitch) * @sin(self.yaw),
        0.0,
    );
    self.target = self.position + dir;
}
pub fn getViewMatrix(self: Camera3D) zm.Mat {
    return zm.lookAtRh(self.position, self.target, self.up);
}

pub fn moveForward(self: *Camera3D, dt: f32) void {
    const dir = zm.normalize3(self.target - self.position);
    const delta = dir * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveBackward(self: *Camera3D, dt: f32) void {
    self.moveForward(-dt);
}

pub fn moveRight(self: *Camera3D, dt: f32) void {
    const dir = zm.normalize3(self.target - self.position);
    const right = zm.normalize3(zm.cross3(dir, self.up));
    const delta = right * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveLeft(self: *Camera3D, dt: f32) void {
    self.moveRight(-dt);
}

pub fn moveUp(self: *Camera3D, dt: f32) void {
    const delta = self.up * zm.splat(zm.Vec, self.speed * dt);
    self.position += delta;
    self.target += delta;
}

pub fn moveDown(self: *Camera3D, dt: f32) void {
    self.moveUp(-dt);
}
