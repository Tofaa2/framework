const std = @import("std");

pub const Entity = packed struct(u64) {
    index: u32,
    generation: u32,

    pub const invalid: Entity = .{ .index = std.math.maxInt(u32), .generation = 0 };

    pub fn eql(self: Entity, other: Entity) bool {
        return self.index == other.index and self.generation == other.generation;
    }

    pub fn format(
        self: Entity,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Entity({},{})", .{ self.index, self.generation });
    }
};

pub const EntitySlot = struct {
    generation: u32,
    alive: bool,
    archetype: u32,
    row: u32,
};
