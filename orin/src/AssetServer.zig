/// Core resource for asynchronous, parallel asset loading.
/// Uses the engine's ThreadPool for background I/O and parsing.
const std = @import("std");
const World = @import("World.zig");
const AssetHandle = @import("Handle.zig").Handle;
const Assets = @import("Assets.zig").Assets;
const typeIdInt = @import("util/type_id.zig").typeIdInt;

pub const AssetServer = @This();

const PathKey = struct {
    type_id: usize,
    path: []const u8,

    pub fn hash(self: PathKey) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&self.type_id));
        h.update(self.path);
        return h.final();
    }

    pub fn eql(self: PathKey, other: PathKey) bool {
        return self.type_id == other.type_id and std.mem.eql(u8, self.path, other.path);
    }
};

const PathContext = struct {
    pub fn hash(self: PathContext, key: PathKey) u64 {
        _ = self;
        return key.hash();
    }
    pub fn eql(self: PathContext, a: PathKey, b: PathKey) bool {
        _ = self;
        return a.eql(b);
    }
};

/// Map of canonical path to existing handle.
load_cache: std.HashMapUnmanaged(PathKey, u32, PathContext, 80) = .{},
mutex: std.Thread.Mutex = .{},
allocator: std.mem.Allocator,

pub fn init(self: *AssetServer, allocator: std.mem.Allocator) void {
    self.* = .{
        .allocator = allocator,
        .load_cache = .{},
        .mutex = .{},
    };
}

pub fn deinit(self: *AssetServer) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    var it = self.load_cache.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.path);
    }
    self.load_cache.deinit(self.allocator);
}

/// Load an asset of type T from the given path asynchronously.
/// Returns a handle immediately. The asset will be populated in Assets(T) once ready.
/// T must satisfy: pub fn load(allocator: Allocator, data: []const u8) !T
pub fn load(self: *AssetServer, comptime T: type, world: *World, path: []const u8) AssetHandle(T) {
    const type_id = typeIdInt(T);
    const ctx = PathContext{};

    self.mutex.lock();
    const key = PathKey{ .type_id = type_id, .path = path };
    if (self.load_cache.getAdapted(key, ctx)) |id| {
        self.mutex.unlock();
        return .{ .id = id };
    }
    self.mutex.unlock();

    if (world.getResource(Assets(T)) == null) {
        const storage = world.allocator.create(Assets(T)) catch @panic("OOM");
        storage.init(world.allocator);
        world.insertOwnedResource(Assets(T), storage);
    }
    var assets = world.getMutResource(Assets(T)).?;
    const handle = assets.reserve();
    self.mutex.lock();
    const owned_path = world.allocator.dupe(u8, path) catch @panic("OOM");
    self.load_cache.putContext(world.allocator, .{ .type_id = type_id, .path = owned_path }, handle.id, ctx) catch @panic("OOM");
    self.mutex.unlock();

    world.thread_pool.spawn(assetLoadTask(T), .{ world, owned_path, handle.id }) catch |err| {
        std.log.err("[orin] failed to spawn asset load task for {s}: {}", .{ path, err });
    };

    return handle;
}

pub fn assetLoadTask(comptime T: type) fn (*World, []const u8, u32) void {
    return struct {
        fn run(world: *World, path: []const u8, handle_id: u32) void {
            const allocator = world.allocator;

            const file_data = std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024 * 100) catch |err| {
                std.log.err("[orin] failed to read asset {s}: {}", .{ path, err });
                return;
            };
            defer allocator.free(file_data);

            const asset = T.load(allocator, file_data) catch |err| {
                std.log.err("[orin] failed to parse asset {s}: {}", .{ path, err });
                return;
            };

            if (world.getMutResource(Assets(T))) |storage| {
                storage.update(allocator, .{ .id = handle_id }, asset) catch |err| {
                    std.log.err("[orin] failed to update asset storage for {s}: {}", .{ path, err });
                    return;
                };
                std.log.debug("[orin] asset load complete: {s}", .{path});
            }
        }
    }.run;
}
