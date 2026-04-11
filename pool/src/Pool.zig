const std = @import("std");
const Handle = @import("Handle.zig").Handle;

pub fn Pool(
    comptime IndexBits: u8,
    comptime CycleBits: u8,
    comptime Resource: type,
    comptime T: type,
) type {
    const H = Handle(IndexBits, CycleBits, Resource);

    const index_mask: u64 = if (IndexBits == 64) ~@as(u64, 0) else ((@as(u64, 1) << IndexBits) - 1);
    const cycle_mask: u64 = if (CycleBits == 64) ~@as(u64, 0) else ((@as(u64, 1) << CycleBits) - 1);

    const GenerationT = if (CycleBits <= 32) u32 else u64;
    const generation_max: GenerationT = if (CycleBits == 64) ~@as(GenerationT, 0) else @as(GenerationT, (1 << CycleBits) - 1);

    return struct {
        const Self = @This();
        pub const HandleType = H;
        pub const ResourceType = Resource;

        generations: []GenerationT,
        alive: []bool,
        data: []T,
        free_list: []u64,
        free_count: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, size: usize) !Self {
            const generations = try allocator.alloc(GenerationT, size);
            errdefer allocator.free(generations);

            @memset(generations, 0);

            const alive = try allocator.alloc(bool, size);
            errdefer allocator.free(alive);

            @memset(alive, false);

            const data = try allocator.alloc(T, size);
            errdefer allocator.free(data);

            const free_list = try allocator.alloc(u64, size);
            errdefer allocator.free(free_list);

            const pool = Self{
                .generations = generations,
                .alive = alive,
                .data = data,
                .free_list = free_list,
                .free_count = size,
                .allocator = allocator,
            };

            var i: usize = 0;
            while (i < size) : (i += 1) {
                free_list[size - 1 - i] = @as(u64, i);
            }

            return pool;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.generations);
            self.allocator.free(self.alive);
            self.allocator.free(self.data);
            self.allocator.free(self.free_list);
            self.* = undefined;
        }

        pub fn capacity(self: Self) usize {
            return self.data.len;
        }

        pub fn available(self: Self) usize {
            return self.free_count;
        }

        pub fn aliveCount(self: Self) usize {
            return self.data.len - self.free_count;
        }

        inline fn slotAlive(self: *const Self, slot: usize, gen: GenerationT) bool {
            return slot < self.data.len and self.alive[slot] and self.generations[slot] == gen;
        }

        pub fn add(self: *Self, item: T) !H {
            if (self.free_count == 0) return error.PoolExhausted;
            return self.addAssumeCapacity(item);
        }

        pub fn addAssumeCapacity(self: *Self, item: T) H {
            self.free_count -= 1;
            const slot = self.free_list[self.free_count];
            self.data[slot] = item;
            self.alive[slot] = true;
            const gen = self.generations[slot];
            const new_gen: GenerationT = if (gen == 0) 1 else gen;
            self.generations[slot] = new_gen;
            return H{ .raw = (slot & index_mask) | ((@as(u64, new_gen) & cycle_mask) << IndexBits) };
        }

        pub fn release(self: *Self, handle: H) void {
            const slot = @as(usize, @intCast(handle.getIndex()));
            const gen = @as(GenerationT, @intCast(handle.getCycle()));

            if (slot >= self.data.len) return;
            if (!self.alive[slot]) return;
            if (self.generations[slot] != gen) return;

            const new_gen = self.generations[slot] + 1;
            self.generations[slot] = if (new_gen > generation_max) 1 else new_gen;
            self.alive[slot] = false;

            self.free_list[self.free_count] = slot;
            self.free_count += 1;
        }

        pub fn get(self: *const Self, handle: H) ?*const T {
            const slot = @as(usize, @intCast(handle.getIndex()));
            const gen = @as(GenerationT, @intCast(handle.getCycle()));
            if (!self.slotAlive(slot, gen)) return null;
            return &self.data[slot];
        }

        pub fn getMut(self: *Self, handle: H) ?*T {
            const slot = @as(usize, @intCast(handle.getIndex()));
            const gen = @as(GenerationT, @intCast(handle.getCycle()));
            if (!self.slotAlive(slot, gen)) return null;
            return &self.data[slot];
        }

        pub fn contains(self: *const Self, handle: H) bool {
            return self.get(handle) != null;
        }

        pub fn clear(self: *Self) void {
            @memset(self.generations, 0);
            @memset(self.alive, false);
            var i: usize = 0;
            const len = self.data.len;
            while (i < len) : (i += 1) {
                self.free_list[i] = @as(u64, i);
            }
            self.free_count = len;
        }

        pub fn replace(self: *Self, handle: H, item: T) bool {
            const slot = @as(usize, @intCast(handle.getIndex()));
            const gen = @as(GenerationT, @intCast(handle.getCycle()));
            if (!self.slotAlive(slot, gen)) return false;
            self.data[slot] = item;
            return true;
        }

        pub fn iterate(self: *const Self) Iterator {
            return .{ .pool = self, .index = 0 };
        }

        pub fn iterateMut(self: *Self) MutIterator {
            return .{ .pool = self, .index = 0 };
        }

        pub fn forEachMut(self: *Self, f: *const fn (handle: H, data: *T) void) void {
            var iter = self.iterateMut();
            while (iter.next()) |item| {
                f(item.handle, item.data);
            }
        }

        pub fn forEachConst(self: *const Self, f: *const fn (handle: H, data: *const T) void) void {
            var iter = self.iterate();
            while (iter.next()) |item| {
                f(item.handle, &item.data);
            }
        }

        pub const Iterator = struct {
            pool: *const Self,
            index: usize,

            pub fn next(it: *Iterator) ?struct { handle: H, data: *const T } {
                const len = it.pool.data.len;
                while (it.index < len) : (it.index += 1) {
                    const slot = it.index;
                    if (it.pool.alive[slot]) {
                        it.index += 1;
                        const gen = it.pool.generations[slot];
                        const raw = (@as(u64, slot) & index_mask) | ((@as(u64, gen) & cycle_mask) << IndexBits);
                        return .{ .handle = H{ .raw = raw }, .data = &it.pool.data[slot] };
                    }
                }
                return null;
            }
        };

        pub const MutIterator = struct {
            pool: *Self,
            index: usize,

            pub fn next(it: *MutIterator) ?struct { handle: H, data: *T } {
                const len = it.pool.data.len;
                while (it.index < len) : (it.index += 1) {
                    const slot = it.index;
                    if (it.pool.alive[slot]) {
                        it.index += 1;
                        const gen = it.pool.generations[slot];
                        const raw = (@as(u64, slot) & index_mask) | ((@as(u64, gen) & cycle_mask) << IndexBits);
                        return .{ .handle = H{ .raw = raw }, .data = &it.pool.data[slot] };
                    }
                }
                return null;
            }
        };

        pub fn items(self: *Self) ItemsIterator {
            return .{ .pool = self, .index = 0 };
        }

        pub const ItemsIterator = struct {
            pool: *Self,
            index: usize,

            pub fn next(it: *ItemsIterator) ?*T {
                const len = it.pool.data.len;
                while (it.index < len) : (it.index += 1) {
                    const slot = it.index;
                    if (it.pool.alive[slot]) {
                        it.index += 1;
                        return &it.pool.data[slot];
                    }
                }
                return null;
            }
        };

        pub fn handles(self: *Self) HandlesIterator {
            return .{ .pool = self, .index = 0 };
        }

        pub const HandlesIterator = struct {
            pool: *Self,
            index: usize,

            pub fn next(it: *HandlesIterator) ?H {
                const len = it.pool.data.len;
                while (it.index < len) : (it.index += 1) {
                    const slot = it.index;
                    if (it.pool.alive[slot]) {
                        it.index += 1;
                        const gen = it.pool.generations[slot];
                        const raw = (@as(u64, slot) & index_mask) | ((@as(u64, gen) & cycle_mask) << IndexBits);
                        return H{ .raw = raw };
                    }
                }
                return null;
            }
        };
    };
}
