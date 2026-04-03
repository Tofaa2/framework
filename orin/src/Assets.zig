/// Resource that stores all assets of a certain type T.
/// Assets are managed via numeric handles (id mapping).
const std = @import("std");
const Handle = @import("Handle.zig").Handle;

pub fn Assets(comptime T: type) type {
    return struct {
        const Self = @This();
        
        /// Internal storage entry for an asset.
        const Entry = struct {
            ptr: ?*T = null,
            status: enum { loading, loaded, failed } = .loading,
        };

        /// Map of handle ID to asset entry.
        items: std.AutoHashMapUnmanaged(u32, Entry) = .{},
        /// Next available ID for new assets.
        next_id: u32 = 0,
        /// Mutex for thread-safe access to handles and storage.
        mutex: std.Thread.Mutex = .{},
        allocator: std.mem.Allocator,
        
        pub fn init(self: *Self, allocator: std.mem.Allocator) void {
            self.* = .{ 
                .allocator = allocator,
                .items = .{},
                .next_id = 0,
                .mutex = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            var it = self.items.valueIterator();
            while (it.next()) |entry| {
                if (entry.ptr) |ptr| {
                    if (@hasDecl(T, "deinit")) {
                        ptr.deinit();
                    }
                    self.allocator.destroy(ptr);
                }
            }
            self.items.deinit(self.allocator);
        }

        /// Get a pointer to an asset. Returns null if not loaded.
        pub fn get(self: *Self, handle: Handle(T)) ?*const T {
            if (!handle.isValid()) return null;
            
            self.mutex.lock();
            defer self.mutex.unlock();

            const entry = self.items.get(handle.id) orelse return null;
            if (entry.status != .loaded) return null;
            return entry.ptr.?;
        }

        /// Insert an asset value and return a new handle.
        pub fn insert(self: *Self, value: T) !Handle(T) {
            self.mutex.lock();
            defer self.mutex.unlock();

            const id = self.next_id;
            self.next_id += 1;
            
            const ptr = try self.allocator.create(T);
            ptr.* = value;
            try self.items.put(self.allocator, id, .{ .ptr = ptr, .status = .loaded });
            
            return Handle(T){ .id = id };
        }

        /// Update an existing handle with a new value.
        pub fn update(self: *Self, allocator: std.mem.Allocator, handle: Handle(T), value: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            const entry = self.items.getPtr(handle.id) orelse return error.InvalidHandle;
            
            // Clean up old value if any
            if (entry.ptr) |old_ptr| {
                if (@hasDecl(T, "deinit")) {
                    old_ptr.deinit();
                }
                allocator.destroy(old_ptr);
            }
            
            const new_ptr = try allocator.create(T);
            new_ptr.* = value;
            
            entry.ptr = new_ptr;
            entry.status = .loaded;
        }

        /// Pre-allocate a handle before the asset is loaded.
        pub fn reserve(self: *Self) Handle(T) {
            self.mutex.lock();
            defer self.mutex.unlock();

            const id = self.next_id;
            self.next_id += 1;
            self.items.put(self.allocator, id, .{ .status = .loading }) catch @panic("OOM");
            
            return Handle(T){ .id = id };
        }
    };
}
