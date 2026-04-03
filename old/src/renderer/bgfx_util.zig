const std = @import("std");

pub inline fn isValid(handle: anytype) bool {
    return handle.idx < std.math.maxInt(u16);
}
