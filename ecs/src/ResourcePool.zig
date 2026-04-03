/// Type-safe, type-keyed resource storage.
/// Resources are singletons keyed by their Zig type — one instance per type.
const std = @import("std");
const typeIdInt = @import("util/type_id.zig").typeIdInt;
const ResourcePool = @This();

const ResourceEntry = struct {
    ptr: *anyopaque,
    destroyFn: *const fn (allocator: std.mem.Allocator, ptr: *anyopaque) void,
};

allocator: std.mem.Allocator,
map: std.AutoHashMapUnmanaged(usize, ResourceEntry),
mutex: std.Thread.Mutex,

pub fn init(self: *ResourcePool, allocator: std.mem.Allocator) void {
    self.* = .{
        .allocator = allocator,
        .map = .{},
        .mutex = .{},
    };
}

pub fn deinit(self: *ResourcePool) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    var it = self.map.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.destroyFn(self.allocator, entry.value_ptr.ptr);
    }
    self.map.deinit(self.allocator);
}

/// Add a resource by value (copied into the pool).
pub fn add(self: *ResourcePool, value: anytype) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const T = @TypeOf(value);
    const id = typeIdInt(T);
    if (self.map.contains(id)) return error.ResourceAlreadyExists;
    
    const ptr = try self.allocator.create(T);
    ptr.* = value;
    try self.map.put(self.allocator, id, .{
        .ptr = ptr,
        .destroyFn = makeDestroyFn(T),
    });
}

/// Add a resource by pointer (pool takes ownership).
pub fn addOwned(self: *ResourcePool, comptime T: type, ptr: *T) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const id = typeIdInt(T);
    if (self.map.contains(id)) return error.ResourceAlreadyExists;
    try self.map.put(self.allocator, id, .{
        .ptr = ptr,
        .destroyFn = makeDestroyFn(T),
    });
}

/// Add a resource by pointer without taking ownership.
pub fn addBorrowed(self: *ResourcePool, comptime T: type, ptr: *T) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    const id = typeIdInt(T);
    if (self.map.contains(id)) return error.ResourceAlreadyExists;
    try self.map.put(self.allocator, id, .{
        .ptr = ptr,
        .destroyFn = struct {
            fn noop(_: std.mem.Allocator, _: *anyopaque) void {}
        }.noop,
    });
}

/// Immutable access. Returns null if resource not found.
pub fn get(self: *ResourcePool, comptime T: type) ?*const T {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const entry = self.map.get(typeIdInt(T)) orelse return null;
    return @as(*const T, @ptrCast(@alignCast(entry.ptr)));
}

/// Mutable access. Returns null if resource not found.
pub fn getMut(self: *ResourcePool, comptime T: type) ?*T {
    self.mutex.lock();
    defer self.mutex.unlock();
    
    const entry = self.map.get(typeIdInt(T)) orelse return null;
    return @as(*T, @ptrCast(@alignCast(entry.ptr)));
}

pub fn has(self: *ResourcePool, comptime T: type) bool {
    self.mutex.lock();
    defer self.mutex.unlock();
    return self.map.contains(typeIdInt(T));
}

fn makeDestroyFn(comptime T: type) *const fn (std.mem.Allocator, *anyopaque) void {
    return struct {
        fn destroy(allocator: std.mem.Allocator, raw: *anyopaque) void {
            const typed: *T = @ptrCast(@alignCast(raw));
            if (@hasDecl(T, "deinit")) {
                typed.deinit();
            }
            allocator.destroy(typed);
        }
    }.destroy;
}
