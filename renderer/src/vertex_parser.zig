const std = @import("std");
const bgfx = @import("bgfx").bgfx;

// Per-field override descriptor.
// All fields are optional — only set what you want to override.
pub const FieldInfo = struct {
    attrib: ?bgfx.Attrib = null,
    attrib_type: ?bgfx.AttribType = null,
    num: ?u8 = null,
    normalized: bool = false,
    as_int: bool = false,
};

// The info map you pass alongside your vertex type.
// Keys must match field names exactly.
// e.g.  &.{ .pos = .{ .attrib = .Position }, .uv = .{} }
pub fn VertexInfo(comptime Vertex: type) type {
    const fields = std.meta.fields(Vertex);
    var fields_out: [fields.len]std.builtin.Type.StructField = undefined;

    for (fields, 0..) |f, i| {
        fields_out[i] = .{
            .name = f.name,
            .type = FieldInfo,
            .default_value_ptr = &FieldInfo{},

            .is_comptime = false,
            .alignment = @alignOf(FieldInfo),
        };
    }

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields_out,
        .decls = &.{},
        .is_tuple = false,
    } });
}

// Comptime name → Attrib inference table.
// Exact match only — unknown names cause a compile error.
const AttribName = struct { name: []const u8, attrib: bgfx.Attrib };

const attrib_name_table = [_]AttribName{
    .{ .name = "position", .attrib = .Position },
    .{ .name = "normal", .attrib = .Normal },
    .{ .name = "tangent", .attrib = .Tangent },
    .{ .name = "bitangent", .attrib = .Bitangent },
    .{ .name = "color0", .attrib = .Color0 },
    .{ .name = "color1", .attrib = .Color1 },
    .{ .name = "color2", .attrib = .Color2 },
    .{ .name = "color3", .attrib = .Color3 },
    .{ .name = "indices", .attrib = .Indices },
    .{ .name = "weight", .attrib = .Weight },
    .{ .name = "texcoord0", .attrib = .TexCoord0 },
    .{ .name = "texcoord1", .attrib = .TexCoord1 },
    .{ .name = "texcoord2", .attrib = .TexCoord2 },
    .{ .name = "texcoord3", .attrib = .TexCoord3 },
    .{ .name = "texcoord4", .attrib = .TexCoord4 },
    .{ .name = "texcoord5", .attrib = .TexCoord5 },
    .{ .name = "texcoord6", .attrib = .TexCoord6 },
    .{ .name = "texcoord7", .attrib = .TexCoord7 },
};

fn inferAttrib(comptime name: []const u8) bgfx.Attrib {
    for (attrib_name_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.attrib;
    }
    @compileError("bgfx vertex layout: field '" ++ name ++
        "' does not match any known Attrib name. " ++
        "Provide an explicit FieldInfo override for this field.");
}

// Comptime Zig type → (AttribType, num) inference.
// Handles scalar and fixed-size array cases.
const TypeMapping = struct { attrib_type: bgfx.AttribType, num: u8 };

fn inferTypeMapping(comptime T: type) TypeMapping {
    return switch (@typeInfo(T)) {
        .float => |f| switch (f.bits) {
            16 => .{ .attrib_type = .Half, .num = 1 },
            32 => .{ .attrib_type = .Float, .num = 1 },
            else => @compileError("bgfx vertex layout: unsupported float width " ++
                std.fmt.comptimePrint("{}", .{f.bits})),
        },
        .int => |i| switch (i.signedness) {
            .unsigned => switch (i.bits) {
                8 => .{ .attrib_type = .Uint8, .num = 1 },
                10 => .{ .attrib_type = .Uint10, .num = 1 },
                else => @compileError("bgfx vertex layout: unsupported unsigned int width"),
            },
            .signed => switch (i.bits) {
                16 => .{ .attrib_type = .Int16, .num = 1 },
                else => @compileError("bgfx vertex layout: unsupported signed int width"),
            },
        },
        .array => |arr| blk: {
            if (arr.len < 1 or arr.len > 4)
                @compileError("bgfx vertex layout: array length must be 1–4, got " ++
                    std.fmt.comptimePrint("{}", .{arr.len}));
            const child = inferTypeMapping(arr.child);
            break :blk .{ .attrib_type = child.attrib_type, .num = arr.len };
        },
        else => @compileError("bgfx vertex layout: cannot infer AttribType from type " ++
            @typeName(T)),
    };
}

//   Vertex       — your vertex struct type
//   info         — optional VertexInfo(Vertex) with per-field overrides
//   renderer     — passed to bgfx.VertexLayout.begin()
pub fn createLayout(
    comptime Vertex: type,
    comptime info: VertexInfo(Vertex),
    renderer: bgfx.RendererType,
) bgfx.VertexLayout {
    comptime {
        // Validate Vertex is a plain struct
        switch (@typeInfo(Vertex)) {
            .@"struct" => {},
            else => @compileError("bgfx vertex layout: expected a struct type, got " ++
                @typeName(Vertex)),
        }
    }

    var layout: bgfx.VertexLayout = undefined;
    _ = layout.begin(renderer);

    const fields = comptime std.meta.fields(Vertex);

    inline for (fields) |field| {
        const override: FieldInfo = @field(info, field.name);

        // Resolve attrib semantic
        const attrib: bgfx.Attrib = comptime if (override.attrib) |a| a else inferAttrib(field.name);

        // Resolve type mapping (attrib_type + num)
        const inferred = comptime inferTypeMapping(field.type);

        const attrib_type: bgfx.AttribType = comptime if (override.attrib_type) |t| t else inferred.attrib_type;

        const num: u8 = comptime if (override.num) |n| n else inferred.num;

        _ = layout.add(attrib, num, attrib_type, override.normalized, override.as_int);
    }

    layout.end();
    return layout;
}
