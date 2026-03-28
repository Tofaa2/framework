const std = @import("std");
const root = @import("../root.zig");

pub const PhysicsPlugin = root.Plugin.init(plugin_build);

/// Emitted each frame for each overlapping AABB pair.
/// Read via `app.resources.get(PhysicsSystem.CollisionEvents)`.
pub const CollisionEvent = struct {
    entity_a: root.Entity,
    entity_b: root.Entity,
    /// Collision normal pointing FROM entity_b TO entity_a (unit vector).
    normal: [3]f32,
    /// Penetration depth along the normal.
    penetration: f32,
    /// True if either collider has is_trigger = true (no physical resolution applied).
    is_trigger: bool,
};

pub const CollisionEvents = struct {
    events: std.ArrayListUnmanaged(CollisionEvent) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CollisionEvents {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CollisionEvents) void {
        self.events.deinit(self.allocator);
    }

    pub fn clear(self: *CollisionEvents) void {
        self.events.clearRetainingCapacity();
    }

    pub fn push(self: *CollisionEvents, event: CollisionEvent) void {
        self.events.append(self.allocator, event) catch {};
    }
};

fn plugin_build(app: *root.App) void {
    app.resources.add(CollisionEvents.init(app.allocator)) catch {};

    app.world.scheduler.buildSystem(clearCollisionEvents)
        // .inPhase(.pre_update)
        .append();

    app.world.scheduler.buildSystem(applyGravity)
        .reads(root.Gravity)
        .writes(root.RigidBody)
        // .inPhase(.pre_update)
        .append();

    app.world.scheduler.buildSystem(integrateVelocity)
        .writes(root.Transform)
        .writes(root.RigidBody)
        // .inPhase(.update)
        .append();

    app.world.scheduler.buildSystem(detectAndResolveCollisions)
        .reads(root.Collider)
        .reads(root.Transform)
        .writes(root.RigidBody)
        // .inPhase(.post_update)
        .append();
}

fn clearCollisionEvents(world: *root.World) void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));
    if (app.resources.getMut(CollisionEvents)) |events| events.clear();
}

fn applyGravity(world: *root.World) void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));
    const dt: f32 = @floatCast(app.time.delta);

    var query = world.view(.{ root.RigidBody, root.Gravity }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const body = query.get(root.RigidBody, entity);
        if (body.is_static) continue;
        const gravity = query.getConst(root.Gravity, entity);
        body.velocity[0] += gravity.acceleration[0] * dt;
        body.velocity[1] += gravity.acceleration[1] * dt;
        body.velocity[2] += gravity.acceleration[2] * dt;
    }
}

fn integrateVelocity(world: *root.World) void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));
    const dt: f32 = @floatCast(app.time.delta);

    var query = world.view(.{ root.Transform, root.RigidBody }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const body = query.get(root.RigidBody, entity);
        if (body.is_static) continue;
        const transform = query.get(root.Transform, entity);

        // Exponential drag
        const drag_factor = @max(0.0, 1.0 - body.drag * dt);
        body.velocity[0] *= drag_factor;
        body.velocity[1] *= drag_factor;
        body.velocity[2] *= drag_factor;

        transform.center[0] += body.velocity[0] * dt;
        transform.center[1] += body.velocity[1] * dt;
        transform.center[2] += body.velocity[2] * dt;
    }
}

const CollidableEntry = struct {
    entity: root.Entity,
    collider: root.Collider,
    center: [3]f32,
    is_static: bool,
};

const TestResult = struct {
    /// Axis index (0=X, 1=Y, 2=Z) of minimum penetration
    axis: u2,
    normal: [3]f32,
    penetration: f32,
};

fn detectAndResolveCollisions(world: *root.World) void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));
    const events = app.resources.getMut(CollisionEvents) orelse return;

    var arena = std.heap.ArenaAllocator.init(app.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var entries: std.ArrayListUnmanaged(CollidableEntry) = .empty;

    var query = world.view(.{ root.Transform, root.Collider }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const transform = query.getConst(root.Transform, entity);
        const collider = query.getConst(root.Collider, entity);
        const is_static = if (world.tryGetConst(root.RigidBody, entity)) |b| b.is_static else true;
        entries.append(alloc, .{
            .entity = entity,
            .collider = collider,
            .center = transform.center,
            .is_static = is_static,
        }) catch continue;
    }

    const n = entries.items.len;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var j: usize = i + 1;
        while (j < n) : (j += 1) {
            const a = &entries.items[i];
            const b = &entries.items[j];
            if (a.is_static and b.is_static) continue;

            const result = testAABB3D(a.collider, a.center, b.collider, b.center) orelse continue;

            const is_trigger = a.collider.is_trigger or b.collider.is_trigger;
            events.push(.{
                .entity_a = a.entity,
                .entity_b = b.entity,
                .normal = result.normal,
                .penetration = result.penetration,
                .is_trigger = is_trigger,
            });

            if (!is_trigger) resolveCollision(world, a, b, result);
        }
    }
}

fn testAABB3D(
    ca: root.Collider,
    center_a: [3]f32,
    cb: root.Collider,
    center_b: [3]f32,
) ?TestResult {
    const wc_a = ca.worldCenter(center_a);
    const wc_b = cb.worldCenter(center_b);

    const dx = wc_a[0] - wc_b[0];
    const dy = wc_a[1] - wc_b[1];
    const dz = wc_a[2] - wc_b[2];

    const ox = (ca.half_extents[0] + cb.half_extents[0]) - @abs(dx);
    const oy = (ca.half_extents[1] + cb.half_extents[1]) - @abs(dy);
    const oz = (ca.half_extents[2] + cb.half_extents[2]) - @abs(dz);

    if (ox <= 0 or oy <= 0 or oz <= 0) return null;

    // Resolve along smallest penetration axis
    if (ox <= oy and ox <= oz) {
        return .{ .axis = 0, .normal = .{ if (dx > 0) 1.0 else -1.0, 0, 0 }, .penetration = ox };
    } else if (oy <= ox and oy <= oz) {
        return .{ .axis = 1, .normal = .{ 0, if (dy > 0) 1.0 else -1.0, 0 }, .penetration = oy };
    } else {
        return .{ .axis = 2, .normal = .{ 0, 0, if (dz > 0) 1.0 else -1.0 }, .penetration = oz };
    }
}

fn resolveCollision(
    world: *root.World,
    a: *const CollidableEntry,
    b: *const CollidableEntry,
    result: TestResult,
) void {
    const body_a = if (!a.is_static) world.tryGet(root.RigidBody, a.entity) else null;
    const body_b = if (!b.is_static) world.tryGet(root.RigidBody, b.entity) else null;
    const transform_a = if (!a.is_static) world.tryGet(root.Transform, a.entity) else null;
    const transform_b = if (!b.is_static) world.tryGet(root.Transform, b.entity) else null;

    const n = result.normal;
    const pen = result.penetration;

    const inv_mass_a: f32 = if (body_a) |ba| 1.0 / ba.mass else 0.0;
    const inv_mass_b: f32 = if (body_b) |bb| 1.0 / bb.mass else 0.0;
    const total_inv_mass = inv_mass_a + inv_mass_b;
    if (total_inv_mass == 0) return;

    // Positional correction proportional to inverse mass
    const correction = pen / total_inv_mass;
    if (transform_a) |ta| {
        ta.center[0] += n[0] * correction * inv_mass_a;
        ta.center[1] += n[1] * correction * inv_mass_a;
        ta.center[2] += n[2] * correction * inv_mass_a;
    }
    if (transform_b) |tb| {
        tb.center[0] -= n[0] * correction * inv_mass_b;
        tb.center[1] -= n[1] * correction * inv_mass_b;
        tb.center[2] -= n[2] * correction * inv_mass_b;
    }

    // Impulse-based velocity resolution along the normal
    const vel_a: [3]f32 = if (body_a) |ba| ba.velocity else .{ 0, 0, 0 };
    const vel_b: [3]f32 = if (body_b) |bb| bb.velocity else .{ 0, 0, 0 };
    const rel_vel_n =
        (vel_a[0] - vel_b[0]) * n[0] +
        (vel_a[1] - vel_b[1]) * n[1] +
        (vel_a[2] - vel_b[2]) * n[2];

    // Only resolve if approaching
    if (rel_vel_n > 0) return;

    const e = @min(
        if (body_a) |ba| ba.restitution else 0.0,
        if (body_b) |bb| bb.restitution else 0.0,
    );
    const impulse = -(1.0 + e) * rel_vel_n / total_inv_mass;

    if (body_a) |ba| {
        ba.velocity[0] += impulse * inv_mass_a * n[0];
        ba.velocity[1] += impulse * inv_mass_a * n[1];
        ba.velocity[2] += impulse * inv_mass_a * n[2];
    }
    if (body_b) |bb| {
        bb.velocity[0] -= impulse * inv_mass_b * n[0];
        bb.velocity[1] -= impulse * inv_mass_b * n[1];
        bb.velocity[2] -= impulse * inv_mass_b * n[2];
    }
}
