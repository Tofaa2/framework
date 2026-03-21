const std = @import("std");
const AssetManager = @This();
const typeId = @import("../utils/type_id.zig").typeIdInt;

pub const Image = @import("../primitive/Image.zig");
pub const Font = @import("../primitive/Font.zig");

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

pub fn init(allocator: std.mem.Allocator) AssetManager {
    return .{
        .allocator = allocator,
        .stores = std.AutoHashMap(usize, AssetStore).init(allocator),
    };
}

pub fn deinit(self: *AssetManager) void {
    var it = self.stores.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.stores.deinit();
}

// ─── Font ────────────────────────────────────────────────────────────────────
pub fn loadFont(self: *AssetManager, path: []const u8, size: u32, atlas_size: u32) !Handle(Font) {
    const font = Font.initFile(path, size, atlas_size);
    return self.loadAsset(Font, font);
}

pub fn getFont(self: *AssetManager, handle: Handle(Font)) ?*Font {
    return self.getAsset(Font, handle);
}

pub fn getFontConst(self: *AssetManager, handle: Handle(Font)) ?*const Font {
    return self.getAsset(Font, handle);
}

pub fn unloadFont(self: *AssetManager, handle: Handle(Font)) void {
    self.unloadAsset(Font, handle);
}

pub fn retainFont(self: *AssetManager, handle: Handle(Font)) Handle(Font) {
    return self.retainAsset(Font, handle);
}


pub fn loadImage(self: *AssetManager, path: []const u8) !Handle(Image) {
    const image = Image.initFile(path);
    return self.loadAsset(Image, image);
}

pub fn loadImageSingleColor(self: *AssetManager, color: Image.Color) !Handle(Image) {
    const image = Image.initSingleColor(color);
    return self.loadAsset(Image, image);
}

pub fn getImage(self: *AssetManager, handle: Handle(Image)) ?*Image {
    return self.getAsset(Image, handle);
}

pub fn getImageConst(self: *AssetManager, handle: Handle(Image)) ?*const Image {
    return self.getAsset(Image, handle);
}

pub fn unloadImage(self: *AssetManager, handle: Handle(Image)) void {
    self.unloadAsset(Image, handle);
}

pub fn retainImage(self: *AssetManager, handle: Handle(Image)) Handle(Image) {
    return self.retainAsset(Image, handle);
}

pub fn loadAsset(self: *AssetManager, comptime T: type, value: T) !Handle(T) {
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
                typed.deinit();
                allocator.destroy(typed);
            }
        }.deinit,
    });
    return Handle(T){ .id = index };
}

pub fn getAsset(self: *AssetManager, comptime T: type, handle: Handle(T)) ?*T {
    const store = self.getStore(T) orelse return null;
    if (handle.id >= store.entries.items.len) return null;
    const entry = &store.entries.items[handle.id];
    if (entry.ref_count == 0) return null;
    return @as(*T, @ptrCast(@alignCast(entry.ptr)));
}

fn unloadAsset(self: *AssetManager, comptime T: type, handle: Handle(T)) void {
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

pub fn retainAsset(self: *AssetManager, comptime T: type, handle: Handle(T)) Handle(T) {
    const store = self.getStore(T) orelse return handle;
    if (handle.id >= store.entries.items.len) return handle;
    store.entries.items[handle.id].ref_count += 1;
    return handle;
}

pub fn getOrCreateStore(self: *AssetManager, comptime T: type) !*AssetStore {
    const id = typeId(T);
    const result = try self.stores.getOrPut(id);
    if (!result.found_existing) {
        result.value_ptr.* = AssetStore.init();
    }
    return result.value_ptr;
}

pub fn getStore(self: *AssetManager, comptime T: type) ?*AssetStore {
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
