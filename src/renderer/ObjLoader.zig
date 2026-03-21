const std = @import("std");
const Vertex = @import("Vertex.zig");
const MeshBuilder = @import("MeshBuilder.zig");
const Color = @import("../primitive/Color.zig");
const Image = @import("../primitive/Image.zig");
const AssetPool = @import("../core/AssetPool.zig");

const Material = struct {
    diffuse: Color,
    diffuse_texture: ?[]const u8 = null,
};

pub const LoadResult = struct {
    texture: AssetPool.Handle(Image) = .invalid,
};

fn parseMtl(allocator: std.mem.Allocator, path: []const u8) !std.StringHashMap(Material) {
    var map = std.StringHashMap(Material).init(allocator);

    const file = std.fs.cwd().openFile(path, .{}) catch return map;
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    var current_name: []const u8 = "";
    var current_diffuse: Color = .white;
    var current_diffuse_texture: ?[]const u8 = null;

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.startsWith(u8, trimmed, "newmtl ")) {
            if (current_name.len > 0) {
                const name_copy = try allocator.dupe(u8, current_name);
                try map.put(name_copy, .{
                    .diffuse = current_diffuse,
                    .diffuse_texture = current_diffuse_texture,
                });
            }
            current_name = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
            current_diffuse = .white;
            current_diffuse_texture = null;
        } else if (std.mem.startsWith(u8, trimmed, "Kd ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed[3..], ' ');
            const r = try std.fmt.parseFloat(f32, parts.next() orelse continue);
            const g = try std.fmt.parseFloat(f32, parts.next() orelse continue);
            const b = try std.fmt.parseFloat(f32, parts.next() orelse continue);
            current_diffuse = .{
                .r = @intFromFloat(r * 255.0),
                .g = @intFromFloat(g * 255.0),
                .b = @intFromFloat(b * 255.0),
                .a = 255,
            };
        } else if (std.mem.startsWith(u8, trimmed, "map_Kd ")) {
            const tex_path = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
            std.debug.print("found map_Kd: {s}\n", .{tex_path});
            current_diffuse_texture = try allocator.dupe(u8, tex_path);
        }
    }
    // save last material
    if (current_name.len > 0) {
        const name_copy = try allocator.dupe(u8, current_name);
        try map.put(name_copy, .{
            .diffuse = current_diffuse,
            .diffuse_texture = current_diffuse_texture,
        });
    }

    return map;
}

pub fn load(allocator: std.mem.Allocator, path: []const u8, builder: *MeshBuilder, asset: *AssetPool) !LoadResult {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    const dir = std.fs.path.dirname(path) orelse ".";

    var positions = try std.ArrayList([3]f32).initCapacity(allocator, 24);
    defer positions.deinit(allocator);
    var tex_coords = try std.ArrayList([2]f32).initCapacity(allocator, 24);
    defer tex_coords.deinit(allocator);
    var normals = try std.ArrayList([3]f32).initCapacity(allocator, 24);
    defer normals.deinit(allocator);

    var materials = std.StringHashMap(Material).init(allocator);
    defer {
        var it = materials.keyIterator();
        while (it.next()) |key| allocator.free(key.*);
        // free texture path strings
        var vit = materials.valueIterator();
        while (vit.next()) |val| {
            if (val.diffuse_texture) |tex| allocator.free(tex);
        }
        materials.deinit();
    }

    var current_color: Color = .white;
    var current_texture: AssetPool.Handle(Image) = .invalid;
    var result = LoadResult{};

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.startsWith(u8, trimmed, "mtllib ")) {
            const mtl_name = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
            const mtl_path = try std.fs.path.join(allocator, &.{ dir, mtl_name });
            defer allocator.free(mtl_path);
            materials.deinit();
            materials = try parseMtl(allocator, mtl_path);
        } else if (std.mem.startsWith(u8, trimmed, "usemtl ")) {
            const mat_name = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
            if (materials.get(mat_name)) |mat| {
                current_color = mat.diffuse;
                if (mat.diffuse_texture) |tex_name| {
                    const full_path = try std.fs.path.join(allocator, &.{ dir, tex_name });
                    defer allocator.free(full_path);
                    // current_texture = Image.initFile(full_path);
                    current_texture = try asset.loadImage(full_path);
                }
                else {
                    // current_texture = null;
                    current_texture = .invalid;
                }
            }
        } else if (std.mem.startsWith(u8, trimmed, "v ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed[2..], ' ');
            const x = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const y = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const z = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            try positions.append(allocator, .{ x, y, z });
        } else if (std.mem.startsWith(u8, trimmed, "vt ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed[3..], ' ');
            const u = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const v = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            try tex_coords.append(allocator, .{ u, v });
        } else if (std.mem.startsWith(u8, trimmed, "vn ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed[3..], ' ');
            const x = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const y = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const z = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            try normals.append(allocator, .{ x, y, z });
        } else if (std.mem.startsWith(u8, trimmed, "f ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed[2..], ' ');
            var face_verts: [4]Vertex = undefined;
            var count: u32 = 0;
            while (parts.next()) |part| {
                if (count >= 4) break;
                var indices = std.mem.splitScalar(u8, part, '/');
                const vi = try std.fmt.parseInt(usize, indices.next() orelse return error.InvalidFormat, 10);
                const vti_str = indices.next();
                var uv: [2]f32 = .{ 0.0, 0.0 };
                if (vti_str) |s| {
                    if (s.len > 0) {
                        const vti = try std.fmt.parseInt(usize, s, 10);
                        if (vti > 0 and vti - 1 < tex_coords.items.len) {
                            uv = tex_coords.items[vti - 1];
                        }
                    }
                }
                const vni_str = indices.next();
                var normal: [3]f32 = .{ 0.0, 1.0, 0.0 };
                if (vni_str) |s| {
                    if (s.len > 0) {
                        const vni = try std.fmt.parseInt(usize, s, 10);
                        if (vni > 0 and vni - 1 < normals.items.len) {
                            normal = normals.items[vni - 1];
                        }
                    }
                }
                const pos = positions.items[vi - 1];
                face_verts[count] = .initWithNormal(pos, current_color, uv, normal);
                count += 1;
            }
            if (count == 3) {
                builder.pushTriangle(face_verts[0], face_verts[1], face_verts[2]);
            } else if (count == 4) {
                builder.pushQuad(face_verts[0], face_verts[1], face_verts[2], face_verts[3]);
            }
        }
    }

    result.texture = current_texture;
    return result;
}
