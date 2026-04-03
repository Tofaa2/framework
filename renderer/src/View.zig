const View = @This();

pub const Map = @import("std").AutoArrayHashMap(u8, View);

id: u8,
name: []const u8,
