/// Phase-based parallel system scheduler.
/// Systems declare component read/write accesses; conflict-free systems within
/// a phase are grouped and executed in parallel via the ThreadPool.
const std = @import("std");
const typeIdInt = @import("util/type_id.zig").typeIdInt;
const ThreadPool = @import("ThreadPool.zig");

const World = @import("World.zig");
const Scheduler = @This();

pub const SystemFn = *const fn (*World) void;

pub const Phase = enum(u8) {
    pre_update = 0,
    update = 1,
    post_update = 2,
    render = 3,
};

pub const Access = enum { read, write };

pub const ComponentAccess = struct {
    id: usize,
    access: Access,
};

pub const System = struct {
    func: SystemFn,
    accesses: std.ArrayListUnmanaged(ComponentAccess),
    phase: Phase,

    pub fn deinit(self: *System, allocator: std.mem.Allocator) void {
        self.accesses.deinit(allocator);
    }

    pub fn conflicts(a: *const System, b: *const System) bool {
        for (a.accesses.items) |ac_a| {
            for (b.accesses.items) |ac_b| {
                if (ac_a.id == ac_b.id) {
                    if (ac_a.access == .write or ac_b.access == .write) return true;
                }
            }
        }
        return false;
    }
};

const SystemGroup = struct {
    phase: Phase,
    /// Indices into Scheduler.systems
    indices: std.ArrayListUnmanaged(usize),

    pub fn deinit(self: *SystemGroup, allocator: std.mem.Allocator) void {
        self.indices.deinit(allocator);
    }
};

pub const SystemBuilder = struct {
    scheduler: *Scheduler,
    func: SystemFn,
    accesses: std.ArrayListUnmanaged(ComponentAccess),
    phase: Phase,

    pub fn inPhase(self: SystemBuilder, phase: Phase) SystemBuilder {
        var b = self;
        b.phase = phase;
        return b;
    }

    pub fn reads(self: SystemBuilder, comptime T: type) SystemBuilder {
        var b = self;
        b.accesses.append(b.scheduler.allocator, .{
            .id = typeIdInt(T),
            .access = .read,
        }) catch @panic("OOM in SystemBuilder.reads");
        return b;
    }

    pub fn writes(self: SystemBuilder, comptime T: type) SystemBuilder {
        var b = self;
        b.accesses.append(b.scheduler.allocator, .{
            .id = typeIdInt(T),
            .access = .write,
        }) catch @panic("OOM in SystemBuilder.writes");
        return b;
    }

    pub fn commit(self: SystemBuilder) void {
        self.scheduler.register(.{
            .func = self.func,
            .accesses = self.accesses,
            .phase = self.phase,
        });
    }
};

allocator: std.mem.Allocator,
thread_pool: *ThreadPool,
systems: std.ArrayListUnmanaged(System),
groups: std.ArrayListUnmanaged(SystemGroup),
dirty: bool,

pub fn init(allocator: std.mem.Allocator, thread_pool: *ThreadPool) Scheduler {
    return .{
        .allocator = allocator,
        .thread_pool = thread_pool,
        .systems = .{},
        .groups = .{},
        .dirty = false,
    };
}

pub fn deinit(self: *Scheduler) void {
    for (self.systems.items) |*sys| sys.deinit(self.allocator);
    self.systems.deinit(self.allocator);
    for (self.groups.items) |*grp| grp.deinit(self.allocator);
    self.groups.deinit(self.allocator);
}

pub fn addSystem(self: *Scheduler, func: SystemFn) SystemBuilder {
    return .{
        .scheduler = self,
        .func = func,
        .accesses = .{},
        .phase = .update,
    };
}

pub fn register(self: *Scheduler, system: System) void {
    self.systems.append(self.allocator, system) catch @panic("OOM in Scheduler.register");
    self.dirty = true;
}

pub fn run(self: *Scheduler, world: *World) void {
    if (self.dirty) {
        self.rebuildGroups();
        self.dirty = false;
    }
    for (self.groups.items) |group| {
        self.runGroupParallel(group, world);
    }
}

fn rebuildGroups(self: *Scheduler) void {
    for (self.groups.items) |*grp| grp.deinit(self.allocator);
    self.groups.clearRetainingCapacity();

    std.mem.sort(System, self.systems.items, {}, struct {
        fn lt(_: void, a: System, b: System) bool {
            return @intFromEnum(a.phase) < @intFromEnum(b.phase);
        }
    }.lt);

    for (self.systems.items) |sys| {
        var placed = false;
        for (self.groups.items) |*grp| {
            if (grp.phase != sys.phase) continue;
            var ok = true;
            for (grp.indices.items) |idx| {
                if (System.conflicts(&sys, &self.systems.items[idx])) { ok = false; break; }
            }
            if (ok) {
                const idx = for (self.systems.items, 0..) |s, i| { if (std.meta.eql(s.func, sys.func) and s.phase == sys.phase) break i; } else unreachable;
                grp.indices.append(self.allocator, idx) catch @panic("OOM");
                placed = true;
                break;
            }
        }
        if (!placed) {
            const idx = for (self.systems.items, 0..) |s, i| { if (std.meta.eql(s.func, sys.func) and s.phase == sys.phase) break i; } else unreachable;
            var grp: SystemGroup = .{ .phase = sys.phase, .indices = .{} };
            grp.indices.append(self.allocator, idx) catch @panic("OOM");
            self.groups.append(self.allocator, grp) catch @panic("OOM");
        }
    }
}

fn runGroupParallel(self: *Scheduler, group: SystemGroup, world: *World) void {
    const n = group.indices.items.len;
    if (n == 0) return;
    if (n == 1) { self.systems.items[group.indices.items[0]].func(world); return; }

    var wg = std.Thread.WaitGroup{};
    for (group.indices.items) |idx| {
        const func = self.systems.items[idx].func;
        wg.start();
        self.thread_pool.pool.spawn(runOne, .{ func, world, &wg }) catch {
            wg.finish();
            func(world);
        };
    }
    wg.wait();
}

fn runOne(func: SystemFn, world: *World, wg: *std.Thread.WaitGroup) void {
    defer wg.finish();
    func(world);
}
