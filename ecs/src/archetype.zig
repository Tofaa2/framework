const std = @import("std");
const Column = @import("column.zig").Column;
const Entity = @import("entity.zig").Entity;
const registry = @import("registry.zig");

pub const ArchetypeId = u32;

pub const Archetype = struct {
    signature: u64,
    id: ArchetypeId,
    entities: std.ArrayListUnmanaged(Entity),
    columns: std.AutoArrayHashMapUnmanaged(u32, Column),
    column_sizes: std.AutoArrayHashMapUnmanaged(u32, usize),

    pub fn deinit(self: *Archetype, allocator: std.mem.Allocator) void {
        var it = self.columns.iterator();
        while (it.next()) |e| {
            e.value_ptr.deinit(allocator);
        }
        self.columns.deinit(allocator);
        self.column_sizes.deinit(allocator);
        self.entities.deinit(allocator);
    }

    pub fn appendRow(
        self: *Archetype,
        allocator: std.mem.Allocator,
        e: Entity,
        sig: u64,
        comptime types: []const type,
        values: anytype,
    ) !usize {
        std.debug.assert(self.signature == sig);
        const row = self.entities.items.len;

        try self.entities.append(allocator, e);
        std.debug.assert(self.entities.items.len == row + 1);

        inline for (0..types.len) |vi| {
            const CT = types[vi];
            const cid = registry.id(CT);
            const stride = registry.elementStride(CT);
            const size = @sizeOf(CT);

            const gop = try self.columns.getOrPut(allocator, cid);
            if (!gop.found_existing) {
                gop.value_ptr.* = Column.init(allocator, size, registry.elementAlign(CT));
                try self.column_sizes.put(allocator, cid, stride);
            }
            _ = try gop.value_ptr.pushUninitialized(allocator);

            const col = self.columns.getPtr(cid).?;
            const dst = col.rowPtr(row)[0..size];
            var tmp = values[vi];
            @memcpy(dst, std.mem.asBytes(&tmp)[0..size]);
        }

        return row;
    }

    pub fn pushBlankRow(
        self: *Archetype,
        allocator: std.mem.Allocator,
        e: Entity,
        sig: u64,
    ) !usize {
        std.debug.assert(self.signature == sig);
        const row = self.entities.items.len;

        try self.entities.append(allocator, e);
        std.debug.assert(self.entities.items.len == row + 1);

        var remaining = sig;
        while (remaining != 0) {
            const cid = @ctz(remaining);
            remaining &= remaining - 1;
            const gop = try self.columns.getOrPut(allocator, @intCast(cid));
            if (!gop.found_existing) {
                gop.value_ptr.* = Column.init(allocator, 16, 1);
            }
            _ = try gop.value_ptr.pushUninitialized(allocator);
        }

        return row;
    }

    pub fn ensureColumn(self: *Archetype, allocator: std.mem.Allocator, cid: u32, comptime T: type) !void {
        const size = @sizeOf(T);
        const align_val = registry.elementAlign(T);
        const stride = registry.elementStride(T);

        if (self.columns.getPtr(cid)) |col| {
            if (col.element_size >= size) return;
            col.deinit(allocator);
            col.* = Column.init(allocator, size, align_val);
            try self.column_sizes.put(allocator, cid, stride);
            return;
        }

        try self.columns.put(allocator, cid, Column.init(allocator, size, align_val));
        try self.column_sizes.put(allocator, cid, stride);
    }

    pub fn getColumn(self: *Archetype, cid: u32) ?*Column {
        return self.columns.getPtr(cid);
    }

    pub fn swapRemoveRow(self: *Archetype, _: std.mem.Allocator, row: usize) !?Entity {
        std.debug.assert(row < self.entities.items.len);
        if (self.entities.items.len == 1) {
            _ = self.entities.pop();
            var it = self.columns.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.swapRemove(row);
            }
            return null;
        }

        if (row == self.entities.items.len - 1) {
            _ = self.entities.pop();
            var it = self.columns.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.swapRemove(row);
            }
            return null;
        }

        const moved = self.entities.items[self.entities.items.len - 1];
        _ = self.entities.swapRemove(row);

        var it = self.columns.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.swapRemove(row);
        }

        return moved;
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    id: ArchetypeId,
    signature: u64,
) !Archetype {
    var arch: Archetype = .{
        .signature = signature,
        .id = id,
        .entities = .empty,
        .columns = .empty,
        .column_sizes = .empty,
    };
    errdefer arch.deinit(allocator);
    try arch.entities.ensureTotalCapacity(allocator, 4);
    return arch;
}
