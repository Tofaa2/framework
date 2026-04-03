/// Type-safe handle to an asset of type T.
/// Assets are stored in the Assets(T) resource and retrieved via this Handle.
const std = @import("std");

pub fn Handle(comptime T: type) type {
    _ = T;
    return struct {
        const Self = @This();
        
        /// Unique ID within the asset pool.
        id: u32,

        pub fn invalid() Self {
            return .{ .id = std.math.maxInt(u32) };
        }

        pub fn isValid(self: Self) bool {
            return self.id != std.math.maxInt(u32);
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.id == other.id;
        }
    };
}
