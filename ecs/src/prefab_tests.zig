const std = @import("std");
const prefab = @import("prefab.zig");
const registry = @import("registry.zig");
const serialize = @import("serialize.zig");
const World = @import("world.zig").World;

const PodP = struct { x: f32, y: f32 };
const PodV = struct { vx: f32, vy: f32 };

const CustomV = struct {
    vx: f32,
    vy: f32,
    pub fn serialize(self: @This(), writer: anytype) !void {
        try writer.writeAll(std.mem.asBytes(&self.vx));
        try writer.writeAll(std.mem.asBytes(&self.vy));
    }
    pub fn deserialize(reader: anytype) !@This() {
        var vx: f32 = undefined;
        var vy: f32 = undefined;
        try reader.readNoEof(std.mem.asBytes(&vx));
        try reader.readNoEof(std.mem.asBytes(&vy));
        return .{ .vx = vx, .vy = vy };
    }
};

test "prefab binary roundtrip and spawn (pod)" {
    const id: u32 = 42;
    const file_buf = try prefab.encodePrefabBinary(std.testing.allocator, id, &.{ PodP, PodV }, .{
        PodP{ .x = 3, .y = 4 },
        PodV{ .vx = 1, .vy = -1 },
    });
    defer std.testing.allocator.free(file_buf);

    var fbs = std.io.fixedBufferStream(file_buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);

    try std.testing.expectEqual(id, owned.id);
    try std.testing.expectEqual(file_buf.len, fbs.pos);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const e = try world.spawnPrefab(owned.asRef());
    const p = world.get(e, PodP).?;
    try std.testing.expectApproxEqAbs(@as(f32, 3), p.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 4), p.y, 1e-6);
    const v = world.get(e, PodV).?;
    try std.testing.expectApproxEqAbs(@as(f32, 1), v.vx, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, -1), v.vy, 1e-6);
}

test "prefab binary with custom serialization roundtrip" {
    try std.testing.expect(serialize.hasCustomSerialization(CustomV));

    const id: u32 = 9;
    const file_buf = try prefab.encodePrefabBinary(std.testing.allocator, id, &.{ PodP, CustomV }, .{
        PodP{ .x = -1, .y = 2.5 },
        CustomV{ .vx = 0.25, .vy = 100 },
    });
    defer std.testing.allocator.free(file_buf);

    var fbs = std.io.fixedBufferStream(file_buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);

    var world = World.init(std.testing.allocator);
    defer world.deinit();
    const e = try world.spawnPrefab(owned.asRef());
    const p = world.get(e, PodP).?;
    try std.testing.expectApproxEqAbs(@as(f32, -1), p.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), p.y, 1e-6);
}

test "prefab single component" {
    const buf = try prefab.encodePrefabBinary(std.testing.allocator, 0, &.{PodV}, .{
        PodV{ .vx = 3, .vy = 4 },
    });
    defer std.testing.allocator.free(buf);

    var fbs = std.io.fixedBufferStream(buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);

    var world = World.init(std.testing.allocator);
    defer world.deinit();
    const e = try world.spawnPrefab(owned.asRef());
    try std.testing.expect(world.get(e, PodP) == null);
    const v = world.get(e, PodV).?;
    try std.testing.expectApproxEqAbs(@as(f32, 3), v.vx, 1e-6);
}

test "prefab spawn many from same ref" {
    const buf = try prefab.encodePrefabBinary(std.testing.allocator, 1, &.{ PodP, PodV }, .{
        PodP{ .x = 1, .y = 2 },
        PodV{ .vx = 0, .vy = 0 },
    });
    defer std.testing.allocator.free(buf);

    var fbs = std.io.fixedBufferStream(buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);
    const r = owned.asRef();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    var n: usize = 0;
    while (n < 20) : (n += 1) {
        const e = try world.spawnPrefab(r);
        const p = world.get(e, PodP).?;
        try std.testing.expectApproxEqAbs(@as(f32, 1), p.x, 1e-6);
    }
    try std.testing.expectEqual(@as(usize, 20), n);
}

test "prefab binary rejects bad magic" {
    var raw: [32]u8 = undefined;
    std.mem.writeInt(u32, raw[0..4], 0xdeadbeef, .little);
    var fbs = std.io.fixedBufferStream(&raw);
    try std.testing.expectError(error.InvalidPrefabMagic, prefab.readPrefabBinary(std.testing.allocator, fbs.reader()));
}

test "prefab binary rejects bad version" {
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(std.testing.allocator);
    try appendU32(&list, std.testing.allocator, prefab.prefab_magic);
    try appendU32(&list, std.testing.allocator, 999);
    var fbs = std.io.fixedBufferStream(list.items);
    try std.testing.expectError(error.UnsupportedPrefabVersion, prefab.readPrefabBinary(std.testing.allocator, fbs.reader()));
}

test "prefab binary truncated payload" {
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(std.testing.allocator);
    try appendU32(&list, std.testing.allocator, prefab.prefab_magic);
    try appendU32(&list, std.testing.allocator, prefab.prefab_version);
    try appendU32(&list, std.testing.allocator, 1);
    try appendU64(&list, std.testing.allocator, 1);
    try appendU32(&list, std.testing.allocator, 1000);
    try list.appendSlice(std.testing.allocator, "short");

    var fbs = std.io.fixedBufferStream(list.items);
    try std.testing.expectError(error.EndOfStream, prefab.readPrefabBinary(std.testing.allocator, fbs.reader()));
}

test "prefab spawns visible to chunked query" {
    const buf = try prefab.encodePrefabBinary(std.testing.allocator, 0, &.{ PodP, PodV }, .{
        PodP{ .x = 0, .y = 0 },
        PodV{ .vx = 0, .vy = 0 },
    });
    defer std.testing.allocator.free(buf);

    var fbs = std.io.fixedBufferStream(buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    var s: usize = 0;
    while (s < 37) : (s += 1) _ = try world.spawnPrefab(owned.asRef());

    var qc = world.queryChunked(&.{ PodP, PodV }, 8);
    var total: usize = 0;
    while (qc.next()) |ch| total += ch.len;
    try std.testing.expectEqual(@as(usize, 37), total);
}

test "prefab spawned entities survive snapshot roundtrip" {
    const buf = try prefab.encodePrefabBinary(std.testing.allocator, 1, &.{ PodP, PodV }, .{
        PodP{ .x = 11, .y = 22 },
        PodV{ .vx = 0.1, .vy = 0.2 },
    });
    defer std.testing.allocator.free(buf);

    var fbs = std.io.fixedBufferStream(buf);
    var owned = try prefab.readPrefabBinary(std.testing.allocator, fbs.reader());
    defer owned.deinit(std.testing.allocator);
    const r = owned.asRef();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = try world.spawnPrefab(r);
    _ = try world.spawnPrefab(r);

    var snap: std.ArrayList(u8) = .{};
    defer snap.deinit(std.testing.allocator);
    try world.writeSnapshot(snap.writer(std.testing.allocator));

    world.reset();
    var snap_reader = std.io.fixedBufferStream(snap.items);
    try world.readSnapshot(snap_reader.reader());

    var q = world.query(&.{ PodP, PodV });
    var n: usize = 0;
    while (q.next()) |_| n += 1;
    try std.testing.expectEqual(@as(usize, 2), n);
}

fn appendU32(list: *std.ArrayList(u8), allocator: std.mem.Allocator, v: u32) !void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, v, .little);
    try list.appendSlice(allocator, &b);
}

fn appendU64(list: *std.ArrayList(u8), allocator: std.mem.Allocator, v: u64) !void {
    var b: [8]u8 = undefined;
    std.mem.writeInt(u64, &b, v, .little);
    try list.appendSlice(allocator, &b);
}
