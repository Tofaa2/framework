const std = @import("std");
const ecs = @import("ecs");
const Scheduler = @import("Scheduler.zig");
const ThreadPool = @import("ThreadPool.zig");
const World = @This();

pub const Entity = ecs.Entity;
pub const PrefabRef = ecs.prefab.PrefabRef;

registry: ecs.World,
scheduler: Scheduler,
thread_pool: *ThreadPool,
allocator: std.mem.Allocator,

pub fn init(self: *World, allocator: std.mem.Allocator, thread_pool: *ThreadPool) !void {
    self.registry = ecs.World.init(allocator);
    self.scheduler = Scheduler.init(allocator, thread_pool);
    self.thread_pool = thread_pool;
    self.allocator = allocator;
}

pub fn deinit(self: *World) void {
    self.scheduler.deinit();
    self.registry.deinit();
}

// ---- Structural ECS ---------------------------------------------------------
// Locking is now handled natively inside ecs.World.

pub fn spawn(self: *World) Entity {
    return self.registry.spawn(&.{}, .{}) catch @panic("ECS: failed to spawn entity");
}

pub fn spawnPrefab(self: *World, prefab: PrefabRef) Entity {
    return self.registry.spawnPrefab(prefab) catch @panic("ECS: failed to spawn prefab");
}

pub fn despawn(self: *World, entity: Entity) void {
    self.registry.despawn(entity);
}

pub fn addComponent(self: *World, entity: Entity, value: anytype) void {
    self.registry.addComponent(entity, @TypeOf(value), value) catch
        @panic("ECS: failed to add component");
}

pub fn removeComponent(self: *World, entity: Entity, comptime T: type) void {
    self.registry.removeComponent(entity, T) catch
        @panic("ECS: failed to remove component");
}

pub fn isAlive(self: *World, entity: Entity) bool {
    return self.registry.isAlive(entity);
}

// ---- Query ------------------------------------------------------------------

pub fn query(self: *World, comptime includes: []const type) ecs.World.QueryIter {
    return self.registry.query(includes);
}

/// Acquire a shared read lock on the ECS archetype storage.
/// Required when calling query() on a World that may be structurally mutated
/// by a concurrent system. Always pair with unlockShared().
pub fn lockShared(self: *World) void {
    self.registry.lockShared();
}

pub fn unlockShared(self: *World) void {
    self.registry.unlockShared();
}

// ---- Component Access -------------------------------------------------------

pub fn getComponent(self: *World, comptime T: type, entity: Entity) ?*T {
    return self.registry.getMut(entity, T);
}

pub fn getComponentConst(self: *World, comptime T: type, entity: Entity) ?T {
    return self.registry.get(entity, T);
}

// ---- Resources --------------------------------------------------------------

pub fn insertResource(self: *World, value: anytype) void {
    self.registry.insertResource(value);
}

pub fn insertResourceIfAbsent(self: *World, value: anytype) void {
    self.registry.insertResourceIfAbsent(value);
}

pub fn insertOwnedResource(self: *World, comptime T: type, ptr: *T) void {
    self.registry.insertOwnedResource(T, ptr);
}

pub fn getResource(self: *World, comptime T: type) ?*const T {
    return self.registry.getResource(T);
}

pub fn getMutResource(self: *World, comptime T: type) ?*T {
    return self.registry.getMutResource(T);
}

pub fn hasResource(self: *World, comptime T: type) bool {
    return self.registry.hasResource(T);
}

// ---- Events -----------------------------------------------------------------

pub fn addEvent(self: *World, comptime E: type) void {
    self.registry.addEvent(E);
}

pub fn sendEvent(self: *World, event: anytype) void {
    self.registry.sendEvent(event);
}

pub fn readEvents(self: *World, comptime E: type) ecs.EventChannel(E).EventReader {
    return self.registry.readEvents(E);
}

pub fn updateEvents(self: *World) void {
    self.registry.updateEvents();
}

// ---- Systems ----------------------------------------------------------------

pub fn addSystem(self: *World, func: Scheduler.SystemFn) Scheduler.SystemBuilder {
    return self.scheduler.addSystem(func);
}
