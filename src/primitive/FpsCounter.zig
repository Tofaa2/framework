const FpsCounter = @This();
samples: [60]f64 = [_]f64{0.016} ** 60, // assume 60fps initially
index: usize = 0,
fps: f64 = 0,

pub fn update(self: *FpsCounter, dt: f64) void {
    self.samples[self.index] = dt;
    self.index = (self.index + 1) % self.samples.len;

    var sum: f64 = 0;
    for (self.samples) |s| sum += s;
    self.fps = @as(f64, @floatFromInt(self.samples.len)) / sum;
}
