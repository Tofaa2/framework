const std = @import("std");
const Resources = @This();
const typeId = @import("../utils/type_id.zig").typeIdInt;

allocator: std.mem.Allocator,
map: std.AutoHashMap(usize, ResourceEntry),

pub fn init(allocator: std.mem.Allocator) Resources {
    return .{
        .allocator = allocator,
        .map = std.AutoHashMap(usize, ResourceEntry).init(allocator),
    };
}

pub fn deinit(self: *Resources) void {
    var it = self.map.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.destroyFn(self.allocator, entry.value_ptr.ptr);
    }
    self.map.deinit();
}

/// Add a resource by value (copied into pool)
pub fn add(self: *Resources, value: anytype) !void {
    const T = @TypeOf(value);
    const id = typeId(T);
    if (self.map.contains(id)) {
        return error.ResourceAlreadyExists;
    }
    const ptr = try self.allocator.create(T);
    ptr.* = value;
    try self.map.put(id, .{
        .ptr = ptr,
        .destroyFn = struct {
            fn destroy(
                allocator: std.mem.Allocator,
                raw: *anyopaque,
            ) void {
                const typed = @as(*T, @ptrCast(@alignCast(raw)));
                allocator.destroy(typed);
            }
        }.destroy,
    });
}

/// Add a resource by pointer (takes ownership)
pub fn addOwned(self: *Resources, comptime T: type, ptr: *T) !void {
    const id = typeId(T);
    if (self.map.contains(id)) {
        return error.ResourceAlreadyExists;
    }
    try self.map.put(id, .{
        .ptr = ptr,
        .destroyFn = struct {
            fn destroy(
                allocator: std.mem.Allocator,
                raw: *anyopaque,
            ) void {
                const typed = @as(*T, @ptrCast(@alignCast(raw)));
                allocator.destroy(typed);
            }
        }.destroy,
    });
}

/// Immutable access
pub fn get(self: *Resources, comptime T: type) ?*const T {
    const id = typeId(T);
    const entry = self.map.get(id) orelse return null;
    return @as(*const T, @ptrCast(@alignCast(entry.ptr)));
}

/// Mutable access
pub fn getMut(self: *Resources, comptime T: type) ?*T {
    const id = typeId(T);
    const entry = self.map.get(id) orelse return null;
    return @as(*T, @ptrCast(@alignCast(entry.ptr)));
}

/// Remove and destroy a resource
pub fn remove(self: *Resources, comptime T: type) bool {
    const id = typeId(T);
    const entry = self.map.fetchRemove(id) orelse return false;
    entry.value.destroyFn(self.allocator, entry.value.ptr);
    return true;
}

/// Check existence
pub fn has(self: *Resources, comptime T: type) bool {
    return self.map.contains(typeId(T));
}

const ResourceEntry = struct {
    ptr: *anyopaque,
    destroyFn: *const fn (allocator: std.mem.Allocator, ptr: *anyopaque) void,
};
