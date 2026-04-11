const std = @import("std");

pub fn Handle(
    comptime IndexBits: u8,
    comptime CycleBits: u8,
    comptime Resource: type,
) type {
    const total_bits = IndexBits + CycleBits;
    comptime {
        if (total_bits > 64) {
            @compileError("Handle: index_bits + cycle_bits must be <= 64");
        }
    }

    const index_mask = if (IndexBits == 64) ~@as(u64, 0) else ((@as(u64, 1) << IndexBits) - 1);
    const cycle_mask = if (CycleBits == 64) ~@as(u64, 0) else ((@as(u64, 1) << CycleBits) - 1);
    const invalid_index = index_mask;
    const invalid_cycle = cycle_mask;

    return struct {
        const Self = @This();

        raw: u64,

        pub const index_bits = IndexBits;
        pub const cycle_bits = CycleBits;
        pub const resource = Resource;

        pub fn invalid() Self {
            return .{ .raw = (invalid_index & index_mask) | ((invalid_cycle & cycle_mask) << IndexBits) };
        }

        pub fn isValid(self: Self) bool {
            const idx = self.raw & index_mask;
            const cyc = (self.raw >> IndexBits) & cycle_mask;
            return idx != invalid_index or cyc != invalid_cycle;
        }

        pub fn getIndex(self: Self) u64 {
            return self.raw & index_mask;
        }

        pub fn getCycle(self: Self) u64 {
            return (self.raw >> IndexBits) & cycle_mask;
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.raw == other.raw;
        }
    };
}

pub fn IndexHandle(comptime Resource: type) type {
    return Handle(32, 0, Resource);
}
