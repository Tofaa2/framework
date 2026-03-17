const Self = @This();
const std = @import("std");
const math = @import("math.zig");
const Batch = @import("RenderBatch.zig");
const Color = @import("Color.zig");

pub const Map = std.AutoArrayHashMap(Id, Self);

pub const Id = enum(u8) {
    @"2d" = 0,
    @"3d" = 1,

    // TODO: add render passes
};

id: Id,
proj_mtx: math.Mat = math.identity(),
view_mtx: math.Mat = math.identity(),
model_mtx: math.Mat = math.identity(),
clear_color: Color = .white,

batches: std.ArrayList(Batch) = .empty,
allocator: std.mem.Allocator,

pub fn createBatch(self: *@This()) *Batch {
    const batch = Batch.init(self.allocator, null, null);
    self.batches.append(self.allocator, batch) catch unreachable;
    return &self.batches.items[self.batches.items.len - 1];
}
