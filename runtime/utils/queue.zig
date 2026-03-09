const std = @import("std");
const atomic = std.atomic;

/// A high-performance, lock-free, Single-Producer Single-Consumer queue.
/// T: The event type (e.g., a Union of your window events).
/// capacity: Must be a power of two (e.g., 256, 1024).
pub fn SPSCQueue(comptime T: type, comptime capacity: usize) type {
    // Ensure capacity is a power of two for bitwise optimization
    comptime {
        if (!std.math.isPowerOfTwo(capacity)) {
            @compileError("Capacity must be a power of two for performance masking.");
        }
    }

    return struct {
        const Self = @This();
        const Mask = capacity - 1;

        buffer: [capacity]T = undefined,

        // Cache line padding prevents "False Sharing"
        // between the Producer and Consumer threads.
        write_index: atomic.Value(usize) align(std.atomic.cache_line_size) = atomic.Value(usize).init(0),
        read_index: atomic.Value(usize) align(std.atomic.cache_line_size) = atomic.Value(usize).init(0),

        /// The Producer (Window Thread) calls this.
        /// Returns false if the queue is full.
        pub fn tryPush(self: *Self, item: T) bool {
            const w = self.write_index.load(.monotonic);
            const r = self.read_index.load(.acquire);

            if (w -% r == capacity) return false; // Buffer full

            self.buffer[w & Mask] = item;
            // .release ensures the buffer write is visible before the index update
            self.write_index.store(w +% 1, .release);
            return true;
        }

        /// The Consumer (Render Thread) calls this.
        /// Returns null if the queue is empty.
        pub fn tryPop(self: *Self) ?T {
            const r = self.read_index.load(.monotonic);
            const w = self.write_index.load(.acquire);

            if (r == w) return null; // Buffer empty

            const item = self.buffer[r & Mask];
            // .release ensures the read is finished before the index update
            self.read_index.store(r +% 1, .release);
            return item;
        }
    };
}

/// A double-ended queue (deque) implemented using a ring buffer.
/// Supports O(1) push/pop operations from both ends.
pub fn Deque(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        capacity: usize,
        head: usize, // Index of first element
        tail: usize, // Index one past last element
        len: usize,
        allocator: std.mem.Allocator,

        /// Initialize a deque with the given initial capacity
        pub fn init(allocator: std.mem.Allocator, initial_capacity: usize) !Self {
            const cap = if (initial_capacity == 0) 8 else initial_capacity;
            const items = try allocator.alloc(T, cap);

            return Self{
                .items = items,
                .capacity = cap,
                .head = 0,
                .tail = 0,
                .len = 0,
                .allocator = allocator,
            };
        }

        /// Free the deque's memory
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        /// Get the number of items in the deque
        pub fn length(self: *const Self) usize {
            return self.len;
        }

        /// Check if the deque is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Clear all items from the deque
        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
            self.len = 0;
        }

        /// Add an item to the back of the deque
        pub fn pushBack(self: *Self, item: T) !void {
            if (self.len == self.capacity) {
                try self.grow();
            }

            self.items[self.tail] = item;
            self.tail = (self.tail + 1) % self.capacity;
            self.len += 1;
        }

        /// Add an item to the front of the deque
        pub fn pushFront(self: *Self, item: T) !void {
            if (self.len == self.capacity) {
                try self.grow();
            }

            self.head = if (self.head == 0) self.capacity - 1 else self.head - 1;
            self.items[self.head] = item;
            self.len += 1;
        }

        /// Remove and return an item from the back of the deque
        /// Returns null if the deque is empty
        pub fn popBack(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }

            self.tail = if (self.tail == 0) self.capacity - 1 else self.tail - 1;
            const item = self.items[self.tail];
            self.len -= 1;

            return item;
        }

        /// Remove and return an item from the front of the deque
        /// Returns null if the deque is empty
        pub fn popFront(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }

            const item = self.items[self.head];
            self.head = (self.head + 1) % self.capacity;
            self.len -= 1;

            return item;
        }

        /// Peek at the back item without removing it
        /// Returns null if the deque is empty
        pub fn peekBack(self: *const Self) ?T {
            if (self.len == 0) {
                return null;
            }

            const index = if (self.tail == 0) self.capacity - 1 else self.tail - 1;
            return self.items[index];
        }

        /// Peek at the front item without removing it
        /// Returns null if the deque is empty
        pub fn peekFront(self: *const Self) ?T {
            if (self.len == 0) {
                return null;
            }

            return self.items[self.head];
        }

        /// Get item at index (0 is front, length-1 is back)
        /// Returns null if index is out of bounds
        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.len) {
                return null;
            }

            const actual_index = (self.head + index) % self.capacity;
            return self.items[actual_index];
        }

        /// Set item at index (0 is front, length-1 is back)
        /// Returns error if index is out of bounds
        pub fn set(self: *Self, index: usize, item: T) !void {
            if (index >= self.len) {
                return error.IndexOutOfBounds;
            }

            const actual_index = (self.head + index) % self.capacity;
            self.items[actual_index] = item;
        }

        /// Create a slice containing all items in order
        /// Caller owns the returned memory
        pub fn toSlice(self: *const Self, allocator: std.mem.Allocator) ![]T {
            if (self.len == 0) {
                return &[_]T{};
            }

            var result = try allocator.alloc(T, self.len);

            if (self.head < self.tail) {
                // Contiguous case
                @memcpy(result, self.items[self.head..self.tail]);
            } else {
                // Wrapped case
                const first_part_len = self.capacity - self.head;
                @memcpy(result[0..first_part_len], self.items[self.head..]);
                @memcpy(result[first_part_len..], self.items[0..self.tail]);
            }

            return result;
        }

        /// Grow the deque's capacity
        fn grow(self: *Self) !void {
            const new_capacity = self.capacity * 2;
            const new_items = try self.allocator.alloc(T, new_capacity);

            // Copy items in order to new buffer
            if (self.head < self.tail) {
                // Contiguous case
                @memcpy(new_items[0..self.len], self.items[self.head..self.tail]);
            } else if (self.len > 0) {
                // Wrapped case
                const first_part_len = self.capacity - self.head;
                @memcpy(new_items[0..first_part_len], self.items[self.head..]);
                @memcpy(new_items[first_part_len..self.len], self.items[0..self.tail]);
            }

            self.allocator.free(self.items);
            self.items = new_items;
            self.capacity = new_capacity;
            self.head = 0;
            self.tail = self.len;
        }

        /// Iterator over deque items from front to back
        pub const Iterator = struct {
            deque: *const Self,
            index: usize,

            pub fn next(self: *Iterator) ?T {
                if (self.index >= self.deque.len) {
                    return null;
                }

                const item = self.deque.get(self.index);
                self.index += 1;
                return item;
            }
        };

        /// Get an iterator starting from the front
        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .deque = self,
                .index = 0,
            };
        }

        /// Reverse iterator over deque items from back to front
        pub const ReverseIterator = struct {
            deque: *const Self,
            index: usize,

            pub fn next(self: *ReverseIterator) ?T {
                if (self.index == 0) {
                    return null;
                }

                self.index -= 1;
                return self.deque.get(self.index);
            }
        };

        /// Get a reverse iterator starting from the back
        pub fn reverseIterator(self: *const Self) ReverseIterator {
            return ReverseIterator{
                .deque = self,
                .index = self.len,
            };
        }
    };
}

// =============================================================================
// Tests
// =============================================================================

test "Deque - basic operations" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try std.testing.expect(deque.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), deque.length());

    // Push to back
    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    try std.testing.expectEqual(@as(usize, 3), deque.length());
    try std.testing.expectEqual(@as(i32, 1), deque.peekFront().?);
    try std.testing.expectEqual(@as(i32, 3), deque.peekBack().?);
}

test "Deque - push and pop front" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushFront(1);
    try deque.pushFront(2);
    try deque.pushFront(3);

    try std.testing.expectEqual(@as(i32, 3), deque.popFront().?);
    try std.testing.expectEqual(@as(i32, 2), deque.popFront().?);
    try std.testing.expectEqual(@as(i32, 1), deque.popFront().?);
    try std.testing.expect(deque.popFront() == null);
}

test "Deque - push and pop back" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    try std.testing.expectEqual(@as(i32, 3), deque.popBack().?);
    try std.testing.expectEqual(@as(i32, 2), deque.popBack().?);
    try std.testing.expectEqual(@as(i32, 1), deque.popBack().?);
    try std.testing.expect(deque.popBack() == null);
}

test "Deque - mixed operations" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushFront(2);
    try deque.pushBack(3);
    try deque.pushFront(4);

    // Should be: 4, 2, 1, 3
    try std.testing.expectEqual(@as(i32, 4), deque.popFront().?);
    try std.testing.expectEqual(@as(i32, 3), deque.popBack().?);
    try std.testing.expectEqual(@as(i32, 2), deque.popFront().?);
    try std.testing.expectEqual(@as(i32, 1), deque.popBack().?);
}

test "Deque - grow capacity" {
    var deque = try Deque(i32).init(std.testing.allocator, 2);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3); // Should trigger growth
    try deque.pushBack(4);
    try deque.pushBack(5); // Should trigger another growth

    try std.testing.expectEqual(@as(usize, 5), deque.length());
    try std.testing.expectEqual(@as(i32, 1), deque.get(0).?);
    try std.testing.expectEqual(@as(i32, 5), deque.get(4).?);
}

test "Deque - get and set" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    try std.testing.expectEqual(@as(i32, 2), deque.get(1).?);
    try deque.set(1, 10);
    try std.testing.expectEqual(@as(i32, 10), deque.get(1).?);
}

test "Deque - iterator" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    var iter = deque.iterator();
    try std.testing.expectEqual(@as(i32, 1), iter.next().?);
    try std.testing.expectEqual(@as(i32, 2), iter.next().?);
    try std.testing.expectEqual(@as(i32, 3), iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "Deque - reverse iterator" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    var iter = deque.reverseIterator();
    try std.testing.expectEqual(@as(i32, 3), iter.next().?);
    try std.testing.expectEqual(@as(i32, 2), iter.next().?);
    try std.testing.expectEqual(@as(i32, 1), iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "Deque - toSlice" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    const slice = try deque.toSlice(std.testing.allocator);
    defer std.testing.allocator.free(slice);

    try std.testing.expectEqual(@as(usize, 3), slice.len);
    try std.testing.expectEqual(@as(i32, 1), slice[0]);
    try std.testing.expectEqual(@as(i32, 2), slice[1]);
    try std.testing.expectEqual(@as(i32, 3), slice[2]);
}

test "Deque - clear" {
    var deque = try Deque(i32).init(std.testing.allocator, 4);
    defer deque.deinit();

    try deque.pushBack(1);
    try deque.pushBack(2);
    try deque.pushBack(3);

    deque.clear();

    try std.testing.expect(deque.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), deque.length());
}
