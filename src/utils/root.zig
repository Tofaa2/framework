const std = @import("std");
const builtin = @import("builtin");

/// The runtime-available representation of a Zig type.
pub const TypeInfo = struct {
    name: []const u8,
    id: usize,
    size: usize,
    alignment: usize,

    /// Returns the TypeInfo for any given type T at compile-time.
    pub fn get(comptime T: type) TypeInfo {
        return .{
            .name = @typeName(T),
            // The compiler creates a unique instance of this struct for every 'T'
            .id = @intFromEnum(typeId(T)),
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
        };
    }
};

const TypeId = enum(usize) {
    _,

    pub fn name(self: TypeId) []const u8 {
        if (builtin.mode == .Debug) {
            return std.mem.sliceTo(@as([*:0]const u8, @ptrFromInt(@intFromEnum(self))), 0);
        } else {
            @compileError("Cannot use TypeId.name outside of Debug mode!");
        }
    }
};

fn typeId(comptime T: type) TypeId {
    const Tag = struct {
        var name: u8 = @typeName(T)[0]; // must depend on the type somehow!
        inline fn id() TypeId {
            return @enumFromInt(@intFromPtr(&name));
        }
    };
    return Tag.id();
}

fn typeIdInt(comptime T: type) usize {
    return @intFromEnum(typeId(T));
}
