/// Manages application time, delta timing, and FPS calculation.
/// Provides mechanisms for framerate limiting and performance measurement.
const Self = @This();
const std = @import("std");

/// The starting time in nanoseconds.
start: i128 = 0,
/// The time elapsed since the previous frame in seconds.
delta: f64 = 0,
/// The optional maximum target frames per second.
fps_limit: ?u32 = null,
/// The high-resolution timer for FPS limiting.
timer: std.time.Timer,
/// The high-resolution timer for delta time measurement.
frame_timer: std.time.Timer,
/// The FPS counter that tracks average performance.
fps: FpsCounter = .{},
/// The total number of frames rendered since application start.
current_frame: u512 = 0,

pub const FpsCounter = struct {
    samples: [60]f64 = [_]f64{0.016} ** 60,
    index: usize = 0,
    fps: f64 = 0,

    pub fn update(self: *FpsCounter, dt: f64) void {
        self.samples[self.index] = dt;
        self.index = (self.index + 1) % self.samples.len;
        var sum: f64 = 0;
        for (self.samples) |s| sum += s;
        self.fps = @as(f64, @floatFromInt(self.samples.len)) / sum;
    }
};

pub fn init() Self {
    return .{
        .timer = std.time.Timer.start() catch unreachable,
        .frame_timer = std.time.Timer.start() catch unreachable,
    };
}

pub fn update(self: *Self) void {
    const elapsed_ns = self.frame_timer.lap();
    self.delta = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    self.fps.update(self.delta);
    self.current_frame += 1;
}

pub fn enforceFpsLimit(self: *Self) void {
    const limit = self.fps_limit orelse return;
    const target_ns: u64 = @divTrunc(std.time.ns_per_s, limit);
    const elapsed = self.timer.read();
    if (elapsed < target_ns) {
        while (self.timer.read() < target_ns) {
            std.atomic.spinLoopHint();
        }
    }
    self.timer.reset();
}
