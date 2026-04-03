const std = @import("std");
const ThreadPool = @This();

pool: std.Thread.Pool,

pub fn init(self: *ThreadPool, allocator: std.mem.Allocator) !void {
    try std.Thread.Pool.init(&self.pool, .{ .allocator = allocator });
}

pub fn deinit(self: *ThreadPool) void {
    self.pool.deinit();
}

pub fn spawn(self: *ThreadPool, comptime func: anytype, args: anytype) !void {
    return self.pool.spawn(func, args);
}

pub fn spawnWg(
    self: *ThreadPool,
    wg: *std.Thread.WaitGroup,
    comptime func: anytype,
    args: anytype,
) !void {
    wg.start();
    self.pool.spawn(func, args) catch |err| {
        wg.finish();
        return err;
    };
}
