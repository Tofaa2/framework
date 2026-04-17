/// Named bgfx uniform handle registry.
/// Call getOrCreate() to retrieve (or lazily create) a uniform handle by name.
/// Handles are owned and destroyed on deinit().
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const UniformStore = @This();

const Entry = struct {
    handle: bgfx.UniformHandle,
};

map: std.StringHashMapUnmanaged(Entry),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) UniformStore {
    return .{
        .map = .{},
        .allocator = allocator,
    };
}

pub fn deinit(self: *UniformStore) void {
    var it = self.map.iterator();
    while (it.next()) |entry| {
        bgfx.destroyUniform(entry.value_ptr.handle);
        self.allocator.free(entry.key_ptr.*);
    }
    self.map.deinit(self.allocator);
}

/// Return an existing handle or create a new one.
/// `name` is expected to be a comptime or long-lived string.
pub fn getOrCreate(
    self: *UniformStore,
    name: []const u8,
    uniform_type: bgfx.UniformType,
    num: u16,
) bgfx.UniformHandle {
    if (self.map.get(name)) |e| return e.handle;

    // Null-terminate for the C API
    var buf: [256]u8 = undefined;
    const n = @min(name.len, buf.len - 1);
    @memcpy(buf[0..n], name[0..n]);
    buf[n] = 0;

    const handle = bgfx.createUniform(@ptrCast(&buf), uniform_type, num);
    const owned_name = self.allocator.dupe(u8, name) catch @panic("UniformStore OOM");
    self.map.put(self.allocator, owned_name, .{ .handle = handle }) catch @panic("UniformStore OOM");
    return handle;
}

/// Shorthand for a single vec4 uniform.
pub fn vec4(self: *UniformStore, name: []const u8) bgfx.UniformHandle {
    return self.getOrCreate(name, bgfx.UniformType.Vec4, 1);
}

/// Shorthand for a single mat4 uniform.
pub fn mat4(self: *UniformStore, name: []const u8) bgfx.UniformHandle {
    return self.getOrCreate(name, bgfx.UniformType.Mat4, 1);
}

/// Shorthand for a sampler2D / texture uniform.
pub fn sampler(self: *UniformStore, name: []const u8) bgfx.UniformHandle {
    return self.getOrCreate(name, bgfx.UniformType.Sampler, 1);
}
