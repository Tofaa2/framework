const Self = @This();

start: i128 = 0,
delta: f64 = 0,
last_frame: i128 = 0,

pub fn update(self: *Self, current_time: i128) void {
    if (self.last_frame == 0) {
        self.last_frame = current_time;
        return;
    }
    self.delta = @as(f64, @intFromFloat(current_time - self.last_frame)) / 1_000_000_000.0;
    self.last_frame = current_time;
}
