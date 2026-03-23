const Sound = @This();

path: [:0]const u8, // null-terminated for C interop

pub fn init(path: [:0]const u8) Sound {
    return .{ .path = path };
}
