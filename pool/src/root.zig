const std = @import("std");

pub const Handle = @import("Handle.zig").Handle;
pub const IndexHandle = @import("Handle.zig").IndexHandle;
pub const Pool = @import("Pool.zig").Pool;

test "Handle basic operations" {
    const MyResource = struct {};
    const H = Handle(16, 16, MyResource);

    try std.testing.expect(H.index_bits == 16);
    try std.testing.expect(H.cycle_bits == 16);

    const invalid = H.invalid();
    try std.testing.expect(!invalid.isValid());
}

test "Handle index and cycle extraction" {
    const MyResource = struct {};
    const H = Handle(8, 8, MyResource);

    const raw: u64 = (42 << 0) | (@as(u64, 7) << 8);
    const h = H{ .raw = raw };
    try std.testing.expect(h.getIndex() == 42);
    try std.testing.expect(h.getCycle() == 7);
}

test "Handle equality" {
    const A = struct {};
    const B = struct {};

    const HA = Handle(32, 0, A);
    const HB = Handle(32, 0, B);

    const ha = HA{ .raw = 42 };
    const ha2 = HA{ .raw = 42 };
    const ha3 = HA{ .raw = 43 };

    try std.testing.expect(ha.eql(ha2));
    try std.testing.expect(!ha.eql(ha3));

    _ = HB;
}

test "Pool init and deinit" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    try std.testing.expect(pool.capacity() == 100);
    try std.testing.expect(pool.available() == 100);
    try std.testing.expect(pool.aliveCount() == 0);
}

test "Pool add and get" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h1 = try pool.add(Resource{ .value = 10 });
    const h2 = try pool.add(Resource{ .value = 20 });
    const h3 = try pool.add(Resource{ .value = 30 });

    try std.testing.expect(pool.contains(h1));
    try std.testing.expect(pool.contains(h2));
    try std.testing.expect(pool.contains(h3));

    const r1 = pool.get(h1).?;
    const r2 = pool.get(h2).?;
    const r3 = pool.get(h3).?;

    try std.testing.expect(r1.value == 10);
    try std.testing.expect(r2.value == 20);
    try std.testing.expect(r3.value == 30);

    try std.testing.expect(pool.aliveCount() == 3);
    try std.testing.expect(pool.available() == 97);
}

test "Pool addAssumeCapacity" {
    const Resource = struct {};
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 10);
    defer pool.deinit();

    const h1 = pool.addAssumeCapacity(Resource{});
    const h2 = pool.addAssumeCapacity(Resource{});

    try std.testing.expect(pool.contains(h1));
    try std.testing.expect(pool.contains(h2));
    try std.testing.expect(pool.aliveCount() == 2);
}

test "Pool release" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h1 = try pool.add(Resource{ .value = 10 });
    const h2 = try pool.add(Resource{ .value = 20 });

    try std.testing.expect(pool.aliveCount() == 2);

    pool.release(h1);
    try std.testing.expect(!pool.contains(h1));
    try std.testing.expect(pool.contains(h2));
    try std.testing.expect(pool.aliveCount() == 1);
    try std.testing.expect(pool.available() == 99);
}

test "Pool generation invalidation" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h1 = try pool.add(Resource{ .value = 10 });
    const h1_index = h1.getIndex();
    try std.testing.expect(h1.getCycle() == 1);

    pool.release(h1);

    const h1_again = try pool.add(Resource{ .value = 99 });
    try std.testing.expect(h1_again.getIndex() == h1_index);
    try std.testing.expect(h1_again.getCycle() == 2);

    try std.testing.expect(!pool.contains(h1));
    try std.testing.expect(pool.contains(h1_again));
}

test "Pool getMut" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h = try pool.add(Resource{ .value = 10 });

    const r = pool.get(h).?;
    try std.testing.expect(r.value == 10);

    const rm = pool.getMut(h).?;
    rm.value = 42;

    const r2 = pool.get(h).?;
    try std.testing.expect(r2.value == 42);
}

test "Pool replace" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h = try pool.add(Resource{ .value = 10 });

    try std.testing.expect(pool.replace(h, Resource{ .value = 20 }));
    const r = pool.get(h).?;
    try std.testing.expect(r.value == 20);

    try std.testing.expect(!pool.replace(.{ .raw = 9999 }, Resource{ .value = 99 }));
}

test "Pool clear" {
    const Resource = struct {};
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    _ = try pool.add(Resource{});
    _ = try pool.add(Resource{});
    _ = try pool.add(Resource{});

    try std.testing.expect(pool.aliveCount() == 3);

    pool.clear();

    try std.testing.expect(pool.aliveCount() == 0);
    try std.testing.expect(pool.available() == 100);
}

test "Pool iteration" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    _ = try pool.add(Resource{ .value = 1 });
    _ = try pool.add(Resource{ .value = 2 });
    _ = try pool.add(Resource{ .value = 3 });

    var sum: i32 = 0;
    var count: usize = 0;
    var iter = pool.iterate();
    while (iter.next()) |entry| {
        sum += entry.data.value;
        count += 1;
    }

    try std.testing.expect(sum == 6);
    try std.testing.expect(count == 3);
}

test "Pool iteration with release" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h1 = try pool.add(Resource{ .value = 1 });
    const h2 = try pool.add(Resource{ .value = 2 });
    _ = try pool.add(Resource{ .value = 3 });

    pool.release(h1);
    pool.release(h2);

    var count: usize = 0;
    var iter = pool.iterate();
    while (iter.next()) |entry| {
        _ = entry.handle;
        _ = entry.data;
        count += 1;
    }

    try std.testing.expect(count == 1);
}

test "Pool exhausted" {
    const Resource = struct {};
    const P = Pool(4, 4, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 5);
    defer pool.deinit();

    for (0..5) |_| {
        _ = try pool.add(Resource{});
    }

    try std.testing.expect(pool.available() == 0);

    const result = pool.add(Resource{});
    try std.testing.expect(result == error.PoolExhausted);
}

test "Pool invalid handle" {
    const Resource = struct {};
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const invalid = P.HandleType.invalid();
    try std.testing.expect(!pool.contains(invalid));
    try std.testing.expect(pool.get(invalid) == null);
    try std.testing.expect(pool.getMut(invalid) == null);
}

test "Pool out of bounds handle" {
    const Resource = struct {};
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const out_of_bounds = P.HandleType{ .raw = 1000 << 16 };
    try std.testing.expect(!pool.contains(out_of_bounds));
}

test "Pool re-add after release" {
    const Resource = struct { value: i32 };
    const P = Pool(16, 16, Resource, Resource);

    var pool = try P.init(std.testing.allocator, 100);
    defer pool.deinit();

    const h1 = try pool.add(Resource{ .value = 1 });
    const h2 = try pool.add(Resource{ .value = 2 });

    pool.release(h1);
    pool.release(h2);

    const h3 = try pool.add(Resource{ .value = 100 });
    const h4 = try pool.add(Resource{ .value = 200 });

    try std.testing.expect(!pool.contains(h1));
    try std.testing.expect(!pool.contains(h2));
    try std.testing.expect(pool.contains(h3));
    try std.testing.expect(pool.contains(h4));
}

test "IndexHandle" {
    const MyResource = struct {};
    const H = IndexHandle(MyResource);

    try std.testing.expect(H.index_bits == 32);
    try std.testing.expect(H.cycle_bits == 0);
}
