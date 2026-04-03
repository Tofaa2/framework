const std = @import("std");
const registry = @import("registry.zig");
const serialize = @import("serialize.zig");

pub const prefab_magic: u32 = 0x46504c53;
pub const prefab_version: u32 = 1;

pub const PrefabRef = struct {
    id: u32,
    signature: u64,
    data: []const u8,
};

pub const PrefabOwned = struct {
    id: u32,
    signature: u64,
    data: []u8,

    pub fn asRef(self: *const PrefabOwned) PrefabRef {
        return .{
            .id = self.id,
            .signature = self.signature,
            .data = self.data,
        };
    }

    pub fn deinit(self: *PrefabOwned, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub const PrefabError = error{
    InvalidPrefabMagic,
    UnsupportedPrefabVersion,
    InvalidPrefabJson,
    MissingPrefabId,
    MissingPrefabComponents,
    InvalidPrefabId,
    UnknownPrefabComponent,
    DuplicatePrefabComponent,
    PrefabSignatureMismatch,
};

fn writeU32(w: anytype, v: u32) !void {
    var b: [4]u8 = undefined;
    std.mem.writeInt(u32, &b, v, .little);
    try w.writeAll(&b);
}

fn writeU64(w: anytype, v: u64) !void {
    var b: [8]u8 = undefined;
    std.mem.writeInt(u64, &b, v, .little);
    try w.writeAll(&b);
}

fn readU32(r: anytype) !u32 {
    var b: [4]u8 = undefined;
    try r.readNoEof(&b);
    return std.mem.readInt(u32, &b, .little);
}

fn readU64(r: anytype) !u64 {
    var b: [8]u8 = undefined;
    try r.readNoEof(&b);
    return std.mem.readInt(u64, &b, .little);
}

pub fn writePrefabBinary(writer: anytype, id: u32, signature: u64, payload: []const u8) !void {
    try writeU32(writer, prefab_magic);
    try writeU32(writer, prefab_version);
    try writeU32(writer, id);
    try writeU64(writer, signature);
    try writeU32(writer, @intCast(payload.len));
    try writer.writeAll(payload);
}

pub fn readPrefabBinary(allocator: std.mem.Allocator, reader: anytype) !PrefabOwned {
    const magic = try readU32(reader);
    if (magic != prefab_magic) return error.InvalidPrefabMagic;
    const ver = try readU32(reader);
    if (ver != prefab_version) return error.UnsupportedPrefabVersion;
    const id = try readU32(reader);
    const sig = try readU64(reader);
    const len = try readU32(reader);
    const data = try allocator.alloc(u8, len);
    errdefer allocator.free(data);
    try reader.readNoEof(data);
    return .{ .id = id, .signature = sig, .data = data };
}

pub fn encodePrefabBinary(allocator: std.mem.Allocator, id: u32, comptime types: []const type, values: anytype) ![]u8 {
    if (types.len != 0) {
        const V = @TypeOf(values);
        const fields = std.meta.fields(V);
        if (fields.len != types.len) @compileError("values tuple length must match types");
    }

    const sig = registry.maskMany(types);

    var body: std.ArrayListUnmanaged(u8) = .{};
    defer body.deinit(allocator);
    const w = body.writer(allocator);

    inline for (types, 0..) |T, ti| {
        const val = values[ti];
        const size = @sizeOf(T);
        try writeU32(w, @intCast(size));
        try w.writeAll(std.mem.asBytes(&val)[0..size]);
    }

    var out: std.ArrayListUnmanaged(u8) = .{};
    errdefer out.deinit(allocator);
    const ow = out.writer(allocator);
    try writePrefabBinary(ow, id, sig, body.items);
    return try out.toOwnedSlice(allocator);
}
