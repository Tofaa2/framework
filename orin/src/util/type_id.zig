const std = @import("std");

pub fn typeId(comptime T: type) []const u8 {
    return @typeName(T);
}

pub fn typeIdInt(comptime T: type) usize {
    return comptime std.hash.Wyhash.hash(0, @typeName(T));
}
