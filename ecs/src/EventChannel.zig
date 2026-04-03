/// Ensures events persist long enough for all systems to read them.
const std = @import("std");

/// Returns an EventChannel type for the given event type E.
/// Store one instance per event type as a World resource.
pub fn EventChannel(comptime E: type) type {
    return struct {
        const Self = @This();

        /// Events written in the current and previous frame.
        a: std.ArrayListUnmanaged(E) = .{},
        b: std.ArrayListUnmanaged(E) = .{},
        /// If true, 'a' is the "new" buffer.
        a_is_new: bool = true,
        allocator: std.mem.Allocator,
        mutex: std.Thread.Mutex = .{},

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.a.deinit(self.allocator);
            self.b.deinit(self.allocator);
        }

        /// Enqueue an event for the current frame.
        pub fn send(self: *Self, event: E) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            const new = if (self.a_is_new) &self.a else &self.b;
            try new.append(self.allocator, event);
        }

        /// Returns an iterator-like structure or slices for both buffers.
        /// To keep it simple and performant, we'll provide two slices.
        pub const EventReader = struct {
            old: []const E,
            new: []const E,
        };

        pub fn read(self: *const Self) EventReader {
            if (self.a_is_new) {
                return .{ .old = self.b.items, .new = self.a.items };
            } else {
                return .{ .old = self.a.items, .new = self.b.items };
            }
        }

        /// Swap buffers and clear the oldest one.
        pub fn update(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.a_is_new = !self.a_is_new;
            const new = if (self.a_is_new) &self.a else &self.b;
            new.clearRetainingCapacity();
        }
    };
}
