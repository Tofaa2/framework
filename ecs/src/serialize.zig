const std = @import("std");

/// True when `T` declares both `serialize` and `deserialize` (custom wire format).
pub fn hasCustomSerialization(comptime T: type) bool {
    return @hasDecl(T, "serialize") and @hasDecl(T, "deserialize");
}

/// Fails compilation unless the component provides both hooks (for strict save/network paths).
pub fn assertSerializable(comptime T: type) void {
    if (!hasCustomSerialization(T)) {
        @compileError("component " ++ @typeName(T) ++ " must define pub fn serialize and pub fn deserialize");
    }
}

pub fn assertBundleSerializable(comptime Bundle: type) void {
    const decls: []const std.builtin.Type.Declaration = comptime std.meta.declarations(Bundle);
    inline for (0..decls.len) |k| {
        const d = decls[k];
        const decl = @field(Bundle, d.name);
        if (@TypeOf(decl) == type) {
            assertSerializable(decl);
        }
    }
}

/// Writes one value. Custom: `pub fn serialize(self: T, writer: anytype) !void`. Otherwise copies `@sizeOf(T)` bytes.
pub fn serializeComponent(comptime T: type, value: T, writer: anytype) !void {
    if (comptime hasCustomSerialization(T)) {
        try value.serialize(writer);
    } else {
        try writer.writeAll(std.mem.asBytes(&value));
    }
}

/// Reads one value. Custom: `pub fn deserialize(reader: anytype) !T`. Otherwise reads `@sizeOf(T)` bytes.
pub fn deserializeComponent(comptime T: type, reader: anytype) !T {
    if (comptime hasCustomSerialization(T)) {
        return try T.deserialize(reader);
    } else {
        var buf: [@sizeOf(T)]u8 = undefined;
        try reader.readNoEof(&buf);
        return std.mem.bytesToValue(T, &buf);
    }
}

/// Fixed-size POD roundtrip (legacy helper).
pub fn writeBytes(comptime T: type, value: T, buf: []u8) usize {
    const n = @sizeOf(T);
    std.debug.assert(buf.len >= n);
    @memcpy(buf[0..n], std.mem.asBytes(&value));
    return n;
}

pub fn readBytes(comptime T: type, buf: []const u8) T {
    std.debug.assert(buf.len >= @sizeOf(T));
    return std.mem.bytesToValue(T, buf[0..@sizeOf(T)]);
}

/// Serializes one component into a newly allocated byte slice (custom or `@sizeOf` bytes).
pub fn serializeComponentToSlice(comptime T: type, value: T, allocator: std.mem.Allocator) ![]u8 {
    var list: std.ArrayList(u8) = .{};
    errdefer list.deinit(allocator);
    const w = list.writer(allocator);
    try serializeComponent(T, value, w);
    return try list.toOwnedSlice(allocator);
}
