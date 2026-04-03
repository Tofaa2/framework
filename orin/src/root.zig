pub const App = @import("App.zig");

pub const World = @import("World.zig");
pub const Entity = World.Entity;
pub const PrefabRef = World.PrefabRef;

const ecs = @import("ecs");
pub const prefab = ecs.prefab;
pub const EventChannel = ecs.EventChannel;
pub const ResourcePool = ecs.ResourcePool;

pub const Scheduler = @import("Scheduler.zig");
pub const Phase = Scheduler.Phase;

pub const Time = @import("Time.zig");
pub const ThreadPool = @import("ThreadPool.zig");

pub const Handle = @import("Handle.zig").Handle;
pub const Assets = @import("Assets.zig").Assets;
pub const AssetServer = @import("AssetServer.zig");

pub const typeId = @import("util/type_id.zig").typeId;
pub const typeIdInt = @import("util/type_id.zig").typeIdInt;
