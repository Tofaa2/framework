const std = @import("std");
const orin = @import("orin");

const Position = struct { x: f32, y: f32, z: f32 };
const Velocity = struct { x: f32, y: f32, z: f32 };
const BenchEvent = struct { data: u128 };

const MyAsset = struct {
    allocator: std.mem.Allocator,
    data: []const u8,

    pub fn load(allocator: std.mem.Allocator, file_data: []const u8) !MyAsset {
        return MyAsset{
            .allocator = allocator,
            .data = try allocator.dupe(u8, file_data),
        };
    }

    pub fn deinit(self: *MyAsset) void {
        self.allocator.free(self.data);
    }
};

fn emptySystem(_: *orin.World) void {}

fn runSystemOverhead(allocator: std.mem.Allocator) !void {
    var app = try orin.App.init(allocator, .{ .name = "overhead" });
    defer app.deinit();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        app.addSystem(emptySystem).commit();
    }

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..10) |_| app.tick();

    const end = timer.read();
    const avg_ns = (end - start) / 10;
    std.debug.print("System Overhead (1k systems): {d:.3} ms/tick\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000_000.0});
}

fn movementSystem(world: *orin.World) void {
    world.lockShared();
    defer world.unlockShared();
    var it = world.query(&.{ Position, Velocity });
    while (it.next()) |row| {
        const p = world.getComponent(Position, row.entity).?;
        const v = world.getComponentConst(Velocity, row.entity).?;
        p.x += v.x;
        p.y += v.y;
        p.z += v.z;
    }
}

fn runECSIteration(allocator: std.mem.Allocator, entity_count: usize) !void {
    var app = try orin.App.init(allocator, .{ .name = "ecs" });
    defer app.deinit();

    app.addSystem(movementSystem)
        .reads(Position)
        .reads(Velocity)
        .commit();

    for (0..entity_count) |_| {
        const e = app.world.spawn();
        app.world.addComponent(e, Position{ .x = 0, .y = 0, .z = 0 });
        app.world.addComponent(e, Velocity{ .x = 1, .y = 1, .z = 1 });
    }

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..10) |_| app.tick();

    const end = timer.read();
    const avg_ns = (end - start) / 10;
    std.debug.print("ECS Iteration ({d} entities, Parallel): {d:.3} ms/tick\n", .{ entity_count, @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0 });
}

// ---- Test 3: Event Throughput (Massive Event Bursts) -------------------

fn heavySenderSystem(world: *orin.World) void {
    for (0..5000) |_| {
        world.sendEvent(BenchEvent{ .data = 1 });
    }
}

fn heavyReceiverSystem(world: *orin.World) void {
    const reader = world.readEvents(BenchEvent);
    var count: usize = 0;
    inline for (.{ reader.old, reader.new }) |slice| {
        count += slice.len;
    }
    // Prevent optimization
    if (count == 0 and world.getComponent(Position, .{ .index = 0, .generation = 0 }) != null) @panic("weird");
}

fn runEventThroughput(allocator: std.mem.Allocator) !void {
    var app = try orin.App.init(allocator, .{ .name = "events" });
    defer app.deinit();

    app.addEvent(BenchEvent);

    // Create 3 isolated parallel senders to test Mutex contention
    app.addSystem(heavySenderSystem).inPhase(.update).reads(Position).commit();
    app.addSystem(heavySenderSystem).inPhase(.update).reads(Velocity).commit();
    app.addSystem(heavySenderSystem).inPhase(.update).commit();

    // Receiver in next phase
    app.addSystem(heavyReceiverSystem).inPhase(.post_update).commit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..10) |_| app.tick();

    const end = timer.read();
    const avg_ns = (end - start) / 10;
    std.debug.print("Event Storms (15k concurrent events/tick, 3 senders): {d:.3} ms/tick\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000_000.0});
}

// ---- Test 4: Structural ECS Contention -----------------------------------

// Simulate 4 parallel readers taking RwLock Read locks...
fn readerSystem(world: *orin.World) void {
    world.lockShared();
    defer world.unlockShared();
    var it = world.query(&.{Position});
    var accum: f32 = 0;
    while (it.next()) |row| {
        const p = world.getComponentConst(Position, row.entity).?;
        accum += p.x;
    }
    if (accum == 999999999.0) std.debug.print("{}", .{accum});
}

const SpawnerState = struct {
    entities: std.ArrayListUnmanaged(orin.Entity),
    rng: std.Random.DefaultPrng,
};

// ... While 1 writer takes RwLock Write locks actively mutating structural layout
fn spawnerContentionSystem(world: *orin.World) void {
    var state = world.getMutResource(SpawnerState).?;

    // Spawn 100 new entities
    for (0..100) |_| {
        const e = world.spawn();
        world.addComponent(e, Position{ .x = 1, .y = 1, .z = 1 });
        state.entities.append(world.allocator, e) catch @panic("OOM");
    }

    // Despawn 50 random older entities (testing RwLock write limits)
    if (state.entities.items.len > 1000) {
        for (0..50) |_| {
            const idx = state.rng.random().uintLessThan(usize, state.entities.items.len);
            const e = state.entities.swapRemove(idx);
            world.despawn(e);
        }
    }
}

fn runStructuralContention(allocator: std.mem.Allocator) !void {
    var app = try orin.App.init(allocator, .{ .name = "structural" });
    defer app.deinit();

    app.insertResource(SpawnerState{ .entities = .{}, .rng = std.Random.DefaultPrng.init(0) });
    defer app.world.getMutResource(SpawnerState).?.entities.deinit(allocator);

    // Initial fill
    for (0..10_000) |_| {
        const e = app.world.spawn();
        app.world.addComponent(e, Position{ .x = 1, .y = 1, .z = 1 });
        app.world.getMutResource(SpawnerState).?.entities.append(allocator, e) catch @panic("OOM");
    }

    // Parallel readers
    app.addSystem(readerSystem).inPhase(.update).reads(Velocity).commit();
    app.addSystem(readerSystem).inPhase(.update).reads(Position).commit();
    app.addSystem(readerSystem).inPhase(.update).reads(BenchEvent).commit();

    // The structural mutating phase (has to run without readers because ecs_lock)
    // Wait; if it modifies structural layout, it takes `world.ecs_lock`
    // However, if they are in the same phase, scheduler doesn't know about `spawn()` limits.
    // Wait! `spawnerContentionSystem` modifies `SpawnerState`, so it gets its own scheduling constraint!
    // But `reads(SpawnerState)` vs `writes(SpawnerState)`... system builder does not track resources!
    // Orin engine DOES NOT lock resources out of the box in the scheduler!
    // They run in parallel phase .update if no Component access conflicts!
    // So Spawner AND Readers will run entirely concurrently, bashing the `RwLock` !
    app.addSystem(spawnerContentionSystem).inPhase(.update).commit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    for (0..10) |_| app.tick();

    const end = timer.read();
    const avg_ns = (end - start) / 10;
    std.debug.print("Structural Run Contention (4 Readers, 1 Writer, 10k entities): {d:.3} ms/tick\n", .{@as(f64, @floatFromInt(avg_ns)) / 1_000_000.0});
}

// ---- Test 5: Asset Loading Throughput ------------------------------------
fn runAssetThroughput(allocator: std.mem.Allocator) !void {
    // 1. Setup 1000 tiny dummy files
    std.fs.cwd().makePath("tmp_bench") catch {};
    for (0..1000) |i| {
        var buf: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&buf, "tmp_bench/asset_{d}.txt", .{i});
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = "bench" });
    }

    var app = try orin.App.init(allocator, .{ .name = "assets" });
    defer app.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();

    const server = app.world.getMutResource(orin.AssetServer).?;
    var handles = try allocator.alloc(orin.Handle(MyAsset), 1000);
    defer allocator.free(handles);

    // Queue 1000 simultaneous background loads
    for (0..1000) |i| {
        var buf: [64]u8 = undefined;
        const path = std.fmt.bufPrint(&buf, "tmp_bench/asset_{d}.txt", .{i}) catch unreachable;
        handles[i] = server.load(MyAsset, &app.world, path);
    }

    // Wait for all to finish
    var finished: usize = 0;
    while (finished < 1000) {
        finished = 0;
        app.tick(); // pumps executor if needed
        const assets = app.world.getMutResource(orin.Assets(MyAsset)).?;
        for (handles) |h| {
            if (assets.get(h) != null) {
                finished += 1;
            }
        }
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }

    const end = timer.read();

    // Cleanup generated files
    std.fs.cwd().deleteTree("tmp_bench") catch {};

    std.debug.print("Asset Load Throughput (1000 concurrent I/O assets): {d:.3} ms total\n", .{@as(f64, @floatFromInt(end - start)) / 1_000_000.0});
}

// ---- Main ----------------------------------------------------------------

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("--- Orin Backbone Testing & Benchmarks ---\n", .{});

    try runSystemOverhead(allocator);
    try runECSIteration(allocator, 100_000); // Upped from 10k to 100k
    try runEventThroughput(allocator);
    try runStructuralContention(allocator);
    try runAssetThroughput(allocator);

    std.debug.print("------------------------------------------\n", .{});
}
