const std = @import("std");
const runtime = @import("runtime");
const ecs = runtime.ecs2;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var world = ecs.World();
}

pub const Components = struct {};
