const std = @import("std");
const Time = @This();

/// Delta time in seconds
delta: f32 = 0,
elapsed: f64 = 0,
frame: u64 = 0,

timer: std.time.Timer,

pub fn init() Time {
    return .{
        .timer = std.time.Timer.start() catch unreachable,
    };
}

pub fn update(self: *Time) void {
    const ns = self.timer.lap();
    self.delta = @as(f32, @floatFromInt(ns)) / 1_000_000_000.0;
    self.elapsed += self.delta;
    self.frame += 1;
}

pub fn reset(self: *Time) void {
    self.timer.reset();
}
