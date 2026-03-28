/// Manages the entity component system (ECS) and system scheduling.
/// Acts as the primary container for game entities, components, and their processing logic.
const std = @import("std");
const ecs = @import("ecs");
const World = @This();

/// Entity handle type.
pub const Entity = ecs.Entity;
/// Delegate type for component lifecycle signals.
pub const SignalFunc = ecs.Delegate(.{ *ecs.Registry, Entity });

/// The underlying ECS registry.
registry: ecs.Registry,
/// Allocator used for internal ECS storage and scheduler.
allocator: std.mem.Allocator,
/// Manages the order and execution of systems.
scheduler: *Scheduler,
/// Map of prefab identifiers to their definitions.
prefabs: std.StringHashMap(Prefab),
/// User-defined context pointer.
ctx: ?*anyopaque = null,

pub fn init(allocator: std.mem.Allocator) *World {
    const w = allocator.create(World) catch unreachable;
    w.* = World{
        .registry = ecs.Registry.init(allocator),
        .allocator = allocator,
        .scheduler = Scheduler.init(allocator),
        .prefabs = .init(allocator),
    };
    return w;
}

pub fn deinit(self: *World) void {
    self.scheduler.deinit();
    self.registry.deinit();
    self.allocator.destroy(self);
}

pub inline fn create(self: *World) Entity {
    const entity = self.registry.create();
    return entity;
}

pub fn view(self: *World, comptime includes: anytype, comptime excludes: anytype) ViewType(includes, excludes) {
    return self.registry.view(includes, excludes);
}

pub fn addCreateSignal(self: *World, comptime T: type, func: SignalFunc) void {
    var assured = self.registry.assure(T);
    assured.construction.calls.append(assured.construction.allocator, func) catch unreachable;
}

pub fn addDestroySignal(self: *World, comptime T: type, func: SignalFunc) void {
    var assured = self.registry.assure(T);
    assured.destruction.calls.append(assured.destruction.allocator, func) catch unreachable;
}

pub fn addUpdateSignal(self: *World, comptime T: type, func: SignalFunc) void {
    var assured = self.registry.assure(T);
    assured.update.calls.append(assured.update.allocator, func) catch unreachable;
}

pub fn add(self: *World, entity: Entity, value: anytype) void {
    self.registry.add(entity, value);
}

pub inline fn destroy(self: *World, entity: Entity) void {
    self.registry.destroy(entity);
}

pub inline fn get(self: *World, comptime T: type, entity: Entity) *T {
    return self.registry.get(T, entity);
}

pub inline fn getConst(self: *World, comptime T: type, entity: Entity) *const T {
    return self.registry.getConst(T, entity);
}

pub inline fn tryGet(self: *World, comptime T: type, entity: Entity) ?*T {
    return self.registry.tryGet(T, entity);
}

pub inline fn tryGetConst(self: *World, comptime T: type, entity: Entity) ?T {
    return self.registry.tryGetConst(T, entity);
}

pub inline fn basicView(self: *World, comptime T: type) ecs.BasicView(T) {
    return self.registry.basicView(T);
}

fn ViewType(comptime includes: anytype, comptime excludes: anytype) type {
    if (includes.len == 1 and excludes.len == 0) return ecs.BasicView(includes[0]);
    return ecs.MultiView(includes, excludes);
}

pub fn spawnPrefab(self: *World, prefab_id: []const u8) ?ecs.Entity {
    const prefab = self.prefabs.get(prefab_id) orelse return null;

    const entity = self.registry.create();
    for (prefab.components) |comp| {
        comp.loader(self.registry, entity, comp.data);
    }

    return entity;
}

pub fn registerPrefab(self: *World, prefab: Prefab) void {
    self.prefabs.put(prefab.id, prefab) catch {
        std.log.err("Failed to register prefab with id {s}\n", .{prefab.id});
    };
}

pub const Prefab = struct {
    id: []const u8,
    components: []const PrefabComponent,
    pub const ComponentLoader = *const fn (registry: *ecs.Registry, entity: ecs.Entity, ptr: *const anyopaque) void;
    pub const PrefabComponent = struct {
        loader: ComponentLoader,
        data: *const anyopaque,

        pub fn component(comptime T: type, value: *const T) PrefabComponent {
            const Closures = struct {
                fn load(registry: *ecs.Registry, entity: ecs.Entity, ptr: *const anyopaque) void {
                    const casted_ptr: *const T = @ptrCast(@alignCast(ptr));
                    registry.add(entity, casted_ptr.*);
                }
            };

            return .{
                .loader = Closures.load,
                .data = value,
            };
        }
    };
};

pub const Scheduler = struct {
    systems: SystemList = .empty,
    allocator: std.mem.Allocator,
    dirty: bool = false,
    execution_order: SystemList = .empty,
    groups: GroupList = .empty,
    thread_pool: *std.Thread.Pool,

    const SystemFn = *const fn (*World) void;

    pub const Phase = enum {
        pre_update,
        update,
        post_update,
        render,
    };

    pub const SystemGroup = struct {
        phase: Phase,
        systems: SystemList,
    };

    pub const Access = enum {
        Read,
        Write,
    };

    pub const ComponentAccess = struct {
        id: usize,
        access: Access,
    };

    pub const System = struct {
        func: SystemFn,
        accesses: AccessList,
        phase: Phase,

        pub fn init(func: SystemFn, accesses: []ComponentAccess, phase: Phase) System {
            return .{
                .func = func,
                .accesses = AccessList.fromOwnedSlice(accesses),
                .phase = phase,
            };
        }

        pub fn conflicts(a: *const System, b: *const System) bool {
            for (a.accesses.items) |ac_a| {
                for (b.accesses.items) |ac_b| {
                    if (ac_a.id == ac_b.id) {
                        if (ac_a.access == .Write or ac_b.access == .Write) {
                            return true;
                        }
                    }
                }
            }
            return false;
        }
    };

    pub const SystemBuilder = struct {
        scheduler: *Scheduler,
        func: SystemFn,
        accesses: std.ArrayList(ComponentAccess),
        phase: Phase = .update,

        pub fn inPhase(self: SystemBuilder, phase: Phase) SystemBuilder {
            var m_self = self;
            m_self.phase = phase;
            return m_self;
        }

        pub fn reads(self: SystemBuilder, comptime T: type) SystemBuilder {
            var m_self = self;
            m_self.accesses.append(self.scheduler.allocator, .{ .id = @import("../utils/type_id.zig").typeIdInt(T), .access = .Read }) catch unreachable;
            return m_self;
        }

        pub fn writes(self: SystemBuilder, comptime T: type) SystemBuilder {
            var m_self = self;
            m_self.accesses.append(self.scheduler.allocator, .{ .id = @import("../utils/type_id.zig").typeIdInt(T), .access = .Write }) catch unreachable;
            return m_self;
        }

        pub fn append(self: SystemBuilder) void {
            self.scheduler.append(.{
                .func = self.func,
                .accesses = self.accesses,
                .phase = self.phase,
            });
        }
    };

    const AccessList = std.ArrayList(ComponentAccess);
    const SystemList = std.ArrayList(System);
    const GroupList = std.ArrayList(SystemGroup);

    pub fn init(allocator: std.mem.Allocator) *Scheduler {
        const tp = allocator.create(std.Thread.Pool) catch unreachable;
        std.Thread.Pool.init(tp, .{
            .allocator = allocator,
            .track_ids = true,
        }) catch unreachable;

        const scheduler = allocator.create(Scheduler) catch unreachable;
        scheduler.* = .{
            .allocator = allocator,
            .thread_pool = tp,
        };
        return scheduler;
    }

    pub fn deinit(self: *Scheduler) void {
        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);

        for (self.systems.items) |*sys| {
            sys.accesses.deinit(self.allocator);
        }

        self.systems.deinit(self.allocator);
        self.execution_order.deinit(self.allocator);
        for (self.groups.items) |*group| {
            group.systems.deinit(self.allocator);
        }
        self.groups.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn run(self: *Scheduler, world: *World) void {
        if (self.dirty) {
            self.buildGroups();
            self.dirty = false;
        }

        for (self.groups.items) |group| {
            self.runGroupParallel(group, world);
        }
    }

    fn buildGroups(self: *Scheduler) void {
        for (self.groups.items) |*group| {
            group.systems.deinit(self.allocator);
        }
        self.groups.clearRetainingCapacity();

        std.mem.sort(System, self.systems.items, {}, struct {
            fn lessThan(_: void, a: System, b: System) bool {
                return @intFromEnum(a.phase) < @intFromEnum(b.phase);
            }
        }.lessThan);

        for (self.systems.items) |sys| {
            var placed = false;

            // try to fit into an existing group
            for (self.groups.items) |*group| {
                if (group.phase != sys.phase) continue;

                var can_fit = true;

                for (group.systems.items) |other| {
                    if (System.conflicts(&sys, &other)) {
                        can_fit = false;
                        break;
                    }
                }

                if (can_fit) {
                    group.systems.append(self.allocator, sys) catch unreachable;
                    placed = true;
                    break;
                }
            }

            // otherwise create new group
            if (!placed) {
                var new_group = SystemGroup{
                    .phase = sys.phase,
                    .systems = SystemList.empty,
                };
                new_group.systems.append(self.allocator, sys) catch unreachable;
                self.groups.append(self.allocator, new_group) catch unreachable;
            }
        }
    }

    fn runGroupParallel(self: *Scheduler, group: SystemGroup, world: *World) void {
        var wg = std.Thread.WaitGroup{};
        for (group.systems.items) |sys| {
            wg.start();
            self.thread_pool.spawn(runSystemWg, .{ sys, world, &wg }) catch unreachable;
        }
        wg.wait();
    }

    fn runSystemWg(sys: System, world: *World, wg: *std.Thread.WaitGroup) void {
        defer wg.finish();
        sys.func(world);
    }

    pub fn append(self: *Scheduler, system: System) void {
        self.systems.append(self.allocator, system) catch unreachable;
        self.dirty = true;
    }

    pub fn buildSystem(self: *Scheduler, func: SystemFn) SystemBuilder {
        return SystemBuilder{
            .scheduler = self,
            .func = func,
            .accesses = .empty,
            .phase = .update,
        };
    }
    fn visit(
        self: *Scheduler,
        result: *SystemList,
        visited: []bool,
        i: usize,
    ) void {
        if (visited[i]) return;
        visited[i] = true;

        for (self.systems.items, 0..) |other, j| {
            if (i == j) continue;

            if (System.conflicts(&other, &self.systems.items[i])) {
                self.visit(result, visited, j);
            }
        }

        result.append(self.allocator, self.systems.items[i]) catch unreachable;
    }

    fn buildExecutionOrder(self: *Scheduler) SystemList {
        var result = SystemList.empty;

        const visited = self.allocator.alloc(bool, self.systems.items.len) catch unreachable;
        defer self.allocator.free(visited);

        @memset(visited, false);

        for (self.systems.items, 0..) |_, i| {
            self.visit(&result, visited, i);
        }

        return result;
    }
};
