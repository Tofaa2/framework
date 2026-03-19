const std = @import("std");
const Vertex = @import("Vertex.zig");
const MeshBuilder = @import("MeshBuilder.zig");
const Color = @import("../primitive/Color.zig");

pub fn load(allocator: std.mem.Allocator, path: []const u8, builder: *MeshBuilder) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024 * 100); // 10MB max
    defer allocator.free(content);

    var positions = std.ArrayList([3]f32).initCapacity(allocator, 24) catch unreachable;
    defer positions.deinit(allocator);
    var tex_coords = std.ArrayList([2]f32).initCapacity(allocator, 24) catch unreachable;
    defer tex_coords.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.startsWith(u8, trimmed, "v ")) {
            // vertex position
            var parts = std.mem.tokenizeScalar(u8, trimmed[2..], ' ');
            const x = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const y = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const z = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            try positions.append(allocator, .{ x, y, z });
        } else if (std.mem.startsWith(u8, trimmed, "vt ")) {
            // texture coordinate
            var parts = std.mem.tokenizeScalar(u8, trimmed[3..], ' ');
            const u = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            const v = try std.fmt.parseFloat(f32, parts.next() orelse return error.InvalidFormat);
            try tex_coords.append(allocator, .{ u, v });
        } else if (std.mem.startsWith(u8, trimmed, "f ")) {
            // face — supports v, v/vt, v/vt/vn, v//vn
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
                const pos = positions.items[vi - 1]; // OBJ is 1-indexed
                face_verts[count] = .init(pos, .white, uv);
                count += 1;
            }
            // triangulate — supports tris and quads
            if (count == 3) {
                builder.pushTriangle(face_verts[0], face_verts[1], face_verts[2]);
            } else if (count == 4) {
                builder.pushQuad(face_verts[0], face_verts[1], face_verts[2], face_verts[3]);
            }
        }
    }
}
