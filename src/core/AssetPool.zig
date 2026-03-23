const std = @import("std");
const AssetPool = @This();
const typeId = @import("../utils/type_id.zig").typeIdInt;
const root = @import("../root.zig");
const VertexLayout = @import("bgfx").bgfx.VertexLayout;

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

allocator: std.mem.Allocator,
stores: std.AutoHashMap(usize, AssetStore),

// loading utils

pub fn loadSound(self: *AssetPool, path: [:0]const u8) !Handle(root.Sound) {
    const sound = root.Sound.init(path);
    return self.loadAsset(root.Sound, sound);
}

pub fn loadImage(self: *AssetPool, path: []const u8) !Handle(root.Image) {
    const image = root.Image.initFile(path);
    return self.loadAsset(root.Image, image);
}

pub fn loadFont(self: *AssetPool, path: []const u8, w: f32, size: u32) !Handle(root.Font) {
    return self.loadAsset(root.Font, root.Font.initFile(path, w, size));
}

pub fn loadObj(self: *AssetPool, path: []const u8) !Handle(root.ObjLoader.Obj) {
    const obj = try root.ObjLoader.load(self.allocator, path);
    return self.loadAsset(root.ObjLoader.Obj, obj);
}

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

pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!*AssetPool {
    const pool = try allocator.create(AssetPool);
    pool.* = .{
        .allocator = allocator,
        .stores = std.AutoHashMap(usize, AssetStore).init(allocator),
    };
    return pool;
}

pub fn deinit(self: *AssetPool, allocator: std.mem.Allocator) void {
    var it = self.stores.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.stores.deinit();
    allocator.destroy(self);
}

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

pub fn getAsset(self: *AssetPool, comptime T: type, handle: Handle(T)) ?*T {
    const store = self.getStore(T) orelse return null;
    if (handle.id >= store.entries.items.len) return null;
    const entry = &store.entries.items[handle.id];
    if (entry.ref_count == 0) return null;
    return @as(*T, @ptrCast(@alignCast(entry.ptr)));
}

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

pub fn retainAsset(self: *AssetPool, comptime T: type, handle: Handle(T)) Handle(T) {
    const store = self.getStore(T) orelse return handle;
    if (handle.id >= store.entries.items.len) return handle;
    store.entries.items[handle.id].ref_count += 1;
    return handle;
}

pub fn getOrCreateStore(self: *AssetPool, comptime T: type) !*AssetStore {
    const id = typeId(T);
    const result = try self.stores.getOrPut(id);
    if (!result.found_existing) {
        result.value_ptr.* = AssetStore.init();
    }
    return result.value_ptr;
}

pub fn getStore(self: *AssetPool, comptime T: type) ?*AssetStore {
    return self.stores.getPtr(typeId(T));
}

pub const AssetEntry = struct {
    ptr: *anyopaque,
    ref_count: u32,
    deinitFn: *const fn (allocator: std.mem.Allocator, ptr: *anyopaque) void,
};

pub const AssetStore = struct {
    entries: std.ArrayListUnmanaged(AssetEntry) = .{},

    fn init() AssetStore {
        return .{};
    }

    fn deinit(self: *AssetStore, allocator: std.mem.Allocator) void {
        for (self.entries.items) |*entry| {
            if (entry.ref_count > 0) {
                entry.deinitFn(allocator, entry.ptr);
            }
        }
        self.entries.deinit(allocator);
    }
};
