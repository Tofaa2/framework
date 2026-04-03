const std = @import("std");

pub const Entity = @import("entity.zig").Entity;
pub const EntitySlot = @import("entity.zig").EntitySlot;

pub const registry = @import("registry.zig");

pub const World = @import("world.zig").World;
pub const WorldError = @import("world.zig").Error;

pub const Archetype = @import("archetype.zig").Archetype;
pub const ArchetypeId = @import("archetype.zig").ArchetypeId;

pub const Column = @import("column.zig").Column;

pub const ResourcePool = @import("ResourcePool.zig");
pub const EventChannel = @import("EventChannel.zig").EventChannel;

pub const serialize = @import("serialize.zig");
pub const assertBundleSerializable = serialize.assertBundleSerializable;
pub const assertSerializable = serialize.assertSerializable;

pub const schedule = @import("schedule.zig");
pub const Schedule = schedule.Schedule;
pub const Masks = schedule.Masks;
pub const masksConflict = schedule.masksConflict;

pub const events = @import("events.zig");
pub const prefab = @import("prefab.zig");

// ---- Tests ------------------------------------------------------------------

test "ecs spawn migrate query" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { vx: f32, vy: f32 };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const e0 = try world.spawn(&.{Velocity}, .{Velocity{ .vx = 3, .vy = 4 }});
    try world.addComponent(e0, Position, .{ .x = 10, .y = 20 });

    const p = world.get(e0, Position).?;
    try std.testing.expectApproxEqAbs(@as(f32, 10), p.x, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 20), p.y, 1e-6);

    if (world.getMut(e0, Velocity)) |v| v.vx = 0.5;

    var q = world.query(&.{ Position, Velocity });
    var seen: usize = 0;
    while (q.next()) |hit| {
        try std.testing.expect(world.isAlive(hit.entity));
        seen += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), seen);

    world.despawn(e0);
    try std.testing.expect(!world.isAlive(e0));
}

test "mask conflict rules" {
    const a = Masks{ .read_mask = 0b001, .write_mask = 0b010 };
    const b = Masks{ .read_mask = 0b100, .write_mask = 0b010 };
    try std.testing.expect(masksConflict(a, b));

    const c = Masks{ .read_mask = 0b001, .write_mask = 0 };
    const d = Masks{ .read_mask = 0, .write_mask = 0b001 };
    try std.testing.expect(masksConflict(c, d));

    const e = Masks{ .read_mask = 0b1, .write_mask = 0 };
    const f = Masks{ .read_mask = 0b10, .write_mask = 0 };
    try std.testing.expect(!masksConflict(e, f));
}

test "resources and events" {
    const MyRes = struct { value: i32 };
    const MyEvent = struct { msg: u32 };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    world.insertResource(MyRes{ .value = 42 });
    try std.testing.expectEqual(@as(i32, 42), world.getResource(MyRes).?.value);

    world.addEvent(MyEvent);
    world.sendEvent(MyEvent{ .msg = 7 });
    const reader = world.readEvents(MyEvent);
    try std.testing.expectEqual(@as(usize, 1), reader.new.len);
    try std.testing.expectEqual(@as(u32, 7), reader.new[0].msg);
    world.updateEvents();
}

test "perf spawn and query" {
    const P = struct { x: f32, y: f32 };
    const V = struct { vx: f32, vy: f32 };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const n: usize = 10_000;
    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < n) : (i += 1) {
        _ = try world.spawn(&.{ P, V }, .{
            P{ .x = @floatFromInt(i), .y = 0 },
            V{ .vx = 0, .vy = 0 },
        });
    }
    const spawn_ns = timer.lap();

    timer.reset();
    var q = world.query(&.{ P, V });
    var count: usize = 0;
    while (q.next()) |_| count += 1;
    const query_ns = timer.lap();

    try std.testing.expectEqual(n, count);
    try std.testing.expect(spawn_ns < 5_000_000_000);
    try std.testing.expect(query_ns < 1_000_000_000);
}

test {
    _ = @import("prefab_tests.zig");
}
