/// Manages loading, caching, and reference counting of game assets.
/// Provides specialized loaders for common asset types like images, fonts, and meshes.
const std = @import("std");
const AssetPool = @This();
const typeId = @import("../utils/type_id.zig").typeIdInt;
const root = @import("../root.zig");
const VertexLayout = @import("bgfx").bgfx.VertexLayout;

/// A type-safe handle to an asset loaded by the AssetPool.
pub fn Handle(comptime T: type) type {
    _ = T;
    return struct {
        id: u32,
        pub const invalid = @This(){ .id = std.math.maxInt(u32) };
        pub fn isValid(self: @This()) bool {
            return self.id != std.math.maxInt(u32);
        }
    };
}

/// The allocator used for internal asset storage and loading.
allocator: std.mem.Allocator,
/// Map of type IDs to their respective AssetStores.
stores: std.AutoHashMap(usize, AssetStore),

/// UTILITY FUNCTION:
/// Loads a sound asset from the given path.
pub fn loadSound(self: *AssetPool, path: [:0]const u8) !Handle(root.Sound) {
    const sound = root.Sound.init(path);
    return self.loadAsset(root.Sound, sound);
}

/// UTILITY FUNCTION:
/// Loads an image asset from the given path.
pub fn loadImage(self: *AssetPool, path: []const u8) !Handle(root.Image) {
    const image = root.Image.initFile(path);
    return self.loadAsset(root.Image, image);
}

/// UTILITY FUNCTION:
/// Loads a cubemap from a given set of paths.
pub fn loadCubemap(self: *AssetPool, faces: root.Cubemap.Faces) !Handle(root.Cubemap) {
    const cubemap = try root.Cubemap.initFromFiles(faces);
    return self.loadAsset(root.Cubemap, cubemap);
}

/// UTILITY FUNCTION:
/// Loads a font asset from the given path.
pub fn loadFont(self: *AssetPool, path: []const u8, w: f32, size: u32) !Handle(root.Font) {
    return self.loadAsset(root.Font, root.Font.initFile(path, w, size));
}

/// UTILITY FUNCTION:
/// Loads an OBJ asset from the given path.
pub fn loadObj(self: *AssetPool, path: []const u8) !Handle(root.ObjLoader.Obj) {
    const obj = try root.ObjLoader.load(self.allocator, path);
    return self.loadAsset(root.ObjLoader.Obj, obj);
}

/// UTILITY FUNCTION:
/// Loads a mesh asset from the given path.
pub fn loadMesh(self: *AssetPool, path: []const u8, layout: *const @import("bgfx").bgfx.VertexLayout) !Handle(root.Mesh) {
    var obj = try root.ObjLoader.load(self.allocator, path);
    defer obj.deinit();

    var builder = root.MeshBuilder.init(self.allocator);
    defer builder.deinit();

    var mesh = root.MeshBuilder.buildFromSlices(obj.vertices, obj.indices, layout);

    if (obj.material.diffuse_texture_path) |tex_path| {
        mesh.texture = try self.loadImage(tex_path);
    }

    return self.loadAsset(root.Mesh, mesh);
}

/// Initialize a new AssetPool with the given allocator.
/// This is used internally by the App struct.
pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!*AssetPool {
    const pool = try allocator.create(AssetPool);
    pool.* = .{
        .allocator = allocator,
        .stores = std.AutoHashMap(usize, AssetStore).init(allocator),
    };
    return pool;
}

/// Deinitialize the AssetPool and free all allocated resources.
pub fn deinit(self: *AssetPool, allocator: std.mem.Allocator) void {
    var it = self.stores.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.stores.deinit();
    allocator.destroy(self);
}

/// Load an asset of type T from the given value.
/// This is used internally by the load utility functions.
/// Can be used to store your own custom assets in the AssetPool.
/// This will attempt to wrap around a deinit function if one is present for the type that is being loaded.
pub fn loadAsset(self: *AssetPool, comptime T: type, value: T) !Handle(T) {
    const store = try self.getOrCreateStore(T);
    const ptr = try self.allocator.create(T);
    ptr.* = value;
    const index: u32 = @intCast(store.entries.items.len);
    try store.entries.append(self.allocator, .{
        .ptr = ptr,
        .ref_count = 1,
        .deinitFn = struct {
            fn deinit(allocator: std.mem.Allocator, raw: *anyopaque) void {
                const typed = @as(*T, @ptrCast(@alignCast(raw)));
                if (@hasDecl(T, "deinit")) {
                    typed.deinit();
                }
                allocator.destroy(typed);
            }
        }.deinit,
    });
    return Handle(T){ .id = index };
}

/// Get an asset of type T by its handle.
/// Returns null if the handle is invalid or the asset has been unloaded.
pub fn getAsset(self: *AssetPool, comptime T: type, handle: Handle(T)) ?*T {
    const store = self.getStore(T) orelse return null;
    if (handle.id >= store.entries.items.len) return null;
    const entry = &store.entries.items[handle.id];
    if (entry.ref_count == 0) return null;
    return @as(*T, @ptrCast(@alignCast(entry.ptr)));
}

/// Unload an asset of type T by its handle.
/// This is used internally by the getAsset function.
/// Will attempt to free the asset if the reference count reaches zero.
fn unloadAsset(self: *AssetPool, comptime T: type, handle: Handle(T)) void {
    const store = self.getStore(T) orelse return;
    if (handle.id >= store.entries.items.len) return;
    const entry = &store.entries.items[handle.id];
    if (entry.ref_count == 0) return;
    entry.ref_count -= 1;
    if (entry.ref_count == 0) {
        entry.deinitFn(self.allocator, entry.ptr);
        entry.ptr = undefined;
    }
}

/// Retain an asset of type T by its handle.
/// The reference count of the asset will be incremented.
pub fn retainAsset(self: *AssetPool, comptime T: type, handle: Handle(T)) Handle(T) {
    const store = self.getStore(T) orelse return handle;
    if (handle.id >= store.entries.items.len) return handle;
    store.entries.items[handle.id].ref_count += 1;
    return handle;
}

/// Get or create a store for an asset of type T.
pub fn getOrCreateStore(self: *AssetPool, comptime T: type) !*AssetStore {
    const id = typeId(T);
    const result = try self.stores.getOrPut(id);
    if (!result.found_existing) {
        result.value_ptr.* = AssetStore.init();
    }
    return result.value_ptr;
}

/// Get a store for an asset of type T, if one exists.
/// Returns null if no store exists for the given type.
pub fn getStore(self: *AssetPool, comptime T: type) ?*AssetStore {
    return self.stores.getPtr(typeId(T));
}

/// An asset entry in the AssetPool, containing a pointer to the asset and a reference count.
/// The deinitFn field is optional and will be called when the reference count reaches zero.
pub const AssetEntry = struct {
    /// Pointer to the asset data.
    ptr: *anyopaque,
    /// Reference count for the asset.
    ref_count: u32,
    /// The deinit function for the asset, if one is present.
    deinitFn: *const fn (allocator: std.mem.Allocator, ptr: *anyopaque) void,
};

/// A store for a type of asset, containing a list of AssetEntries.
pub const AssetStore = struct {
    entries: std.ArrayListUnmanaged(AssetEntry) = .{},
    /// Initializes a new empty AssetStore.
    fn init() AssetStore {
        return .{};
    }

    /// Deinitializes the AssetStore, calling the deinitFn of any entries with a non-zero reference count.
    fn deinit(self: *AssetStore, allocator: std.mem.Allocator) void {
        for (self.entries.items) |*entry| {
            if (entry.ref_count > 0) {
                entry.deinitFn(allocator, entry.ptr);
            }
        }
        self.entries.deinit(allocator);
    }
};
