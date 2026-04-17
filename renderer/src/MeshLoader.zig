const std = @import("std");
const zmesh = @import("zmesh");
const math = @import("math");
const bgfx = @import("bgfx").bgfx;
const stb = @import("stb");
const Mesh = @import("Mesh.zig");
const MeshLoader = @This();

var zmesh_init = false;

fn ensureZmesh(allocator: std.mem.Allocator) void {
    if (!zmesh_init) {
        zmesh.init(allocator);
        zmesh_init = true;
    }
}

pub const Error = error{
    OutOfMemory,
    FileNotFound,
    UnsupportedFormat,
    GltfParseFailed,
    GltfLoadFailed,
    NoMeshesInModel,
};

const ObjVert = struct { pos: math.Vec3, norm: math.Vec3, uv: math.Vec2 };

pub const LoadOptions = struct {
    center: bool = false,
    scale: f32 = 1.0,
    flip_uvs: bool = true,
    base_path: []const u8 = "",
};

pub const MaterialDesc = struct {
    name: []const u8,
    diffuse: math.Vec4,
    texture_path: []const u8 = "",
    texture_data: ?[]u8 = null,
    normal_texture_path: []const u8 = "",
    normal_texture_data: ?[]u8 = null,
    metallic_roughness_texture_path: []const u8 = "",
    metallic_roughness_texture_data: ?[]u8 = null,
};

pub const Submesh = struct {
    mesh: Mesh,
    material: MaterialDesc,
};

pub const LoadedModel = struct {
    submeshes: []Submesh,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LoadedModel) void {
        for (self.submeshes) |*s| {
            s.mesh.deinit();
            self.allocator.free(s.material.name);
            self.allocator.free(s.material.texture_path);
            if (s.material.texture_data) |data| {
                self.allocator.free(data);
            }
        }
        self.allocator.free(self.submeshes);
    }
};

pub fn createSphere(allocator: std.mem.Allocator, radius: f32, slices: i32, stacks: i32) !Mesh {
    ensureZmesh(allocator);
    var shape = zmesh.Shape.initParametricSphere(slices, stacks);
    defer shape.deinit();

    shape.scale(radius, radius, radius);
    shape.unweld();

    const vertex_count = shape.positions.len;
    var vertices = try allocator.alloc(Mesh.Vertex, vertex_count);
    errdefer allocator.free(vertices);

    for (shape.positions, 0..) |pos, i| {
        const pos_vec = math.Vec3.new(pos[0], pos[1], pos[2]);
        const normal = pos_vec.normalize();
        vertices[i] = .{
            .position = pos_vec,
            .normal = normal,
            .texcoord0 = if (shape.texcoords) |tc| tc[i] else .{ 0, 0 },
        };
    }

    var indices = try allocator.alloc(u16, shape.indices.len);
    errdefer allocator.free(indices);
    for (shape.indices, 0..) |idx, i| {
        indices[i] = @intCast(idx);
    }

    return Mesh.initStatic(Mesh.Vertex, vertices, indices, .{});
}

pub fn load(allocator: std.mem.Allocator, path: []const u8, options: LoadOptions) !LoadedModel {
    const ext = std.fs.path.extension(path);
    const ext_lower = try allocator.dupe(u8, ext);
    defer allocator.free(ext_lower);

    for (ext_lower) |*c| c.* = std.ascii.toLower(c.*);

    if (std.mem.eql(u8, ext_lower, ".obj")) {
        return loadObj(allocator, path, options);
    }
    if (std.mem.eql(u8, ext_lower, ".gltf") or std.mem.eql(u8, ext_lower, ".glb")) {
        const null_path = try allocator.allocSentinel(u8, path.len, 0);
        @memcpy(null_path, path);
        defer allocator.free(null_path);
        return loadGltf(allocator, null_path, options);
    }
    return Error.UnsupportedFormat;
}

pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8, options: LoadOptions) !Mesh {
    var model = try load(allocator, path, options);
    defer model.deinit();
    if (model.submeshes.len == 0) return Error.NoMeshesInModel;
    return Mesh{
        .buffers = model.submeshes[0].mesh.buffers,
        .layout = model.submeshes[0].mesh.layout,
        .vertex_count = model.submeshes[0].mesh.vertex_count,
        .index_count = model.submeshes[0].mesh.index_count,
        .aabb = model.submeshes[0].mesh.aabb,
    };
}

pub fn loadObj(allocator: std.mem.Allocator, path: []const u8, options: LoadOptions) !LoadedModel {
    const obj_file = std.fs.cwd().openFile(path, .{}) catch return Error.FileNotFound;
    defer obj_file.close();

    const obj_data = try obj_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(obj_data);

    const base_dir = std.fs.path.dirname(path) orelse "";

    var materials: std.StringHashMapUnmanaged(MtlMaterial) = .{};
    defer {
        var it = materials.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.value_ptr.name);
            allocator.free(entry.value_ptr.texture_path);
        }
        materials.deinit(allocator);
    }

    var mtl_path: []const u8 = "";
    var lines = std.mem.splitScalar(u8, obj_data, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "mtllib ")) {
            var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
            _ = parts.next();
            const mtl_name = parts.next() orelse "";
            if (mtl_name.len > 0) {
                if (base_dir.len > 0) {
                    mtl_path = std.fs.path.join(allocator, &.{ base_dir, mtl_name }) catch "";
                } else {
                    mtl_path = try allocator.dupe(u8, mtl_name);
                }
            }
            break;
        }
    }

    if (mtl_path.len > 0) {
        defer allocator.free(mtl_path);
        if (std.fs.cwd().openFile(mtl_path, .{})) |mtl_file| {
            defer mtl_file.close();
            const mtl_data = mtl_file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch "";
            defer allocator.free(mtl_data);
            if (mtl_data.len > 0) {
                parseMtl(mtl_data, base_dir, allocator, &materials);
            }
        } else |_| {}
    }

    var positions: std.ArrayListUnmanaged(math.Vec3) = .{};
    var normals: std.ArrayListUnmanaged(math.Vec3) = .{};
    var texcoords: std.ArrayListUnmanaged(math.Vec2) = .{};
    defer {
        positions.deinit(allocator);
        normals.deinit(allocator);
        texcoords.deinit(allocator);
    }

    var vertices: std.ArrayListUnmanaged(ObjVert) = .{};
    _ = &vertices;
    var indices: std.ArrayListUnmanaged(u32) = .{};
    _ = &indices;
    defer {
        vertices.deinit(allocator);
        indices.deinit(allocator);
    }

    const Group = struct {
        name: []u8,
        start_idx: usize,
        vert_count: usize,
        indices: std.ArrayListUnmanaged(u32),
    };
    var groups: std.ArrayList(Group) = .{};
    defer {
        for (groups.items) |*g| {
            g.indices.deinit(allocator);
        }
        groups.deinit(allocator);
    }

    var pending_mtl: []u8 = try allocator.dupe(u8, "default");

    lines = std.mem.splitScalar(u8, obj_data, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const cmd = parts.next() orelse continue;

        if (std.mem.eql(u8, cmd, "v")) {
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try positions.append(allocator, .{ .x = x, .y = y, .z = z });
        } else if (std.mem.eql(u8, cmd, "vn")) {
            const x = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const y = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            const z = std.fmt.parseFloat(f32, parts.next() orelse continue) catch continue;
            try normals.append(allocator, math.Vec3.normalize(.{ .x = x, .y = y, .z = z }));
        } else if (std.mem.eql(u8, cmd, "vt")) {
            const u = std.fmt.parseFloat(f32, parts.next() orelse "0") catch 0.0;
            const v_str = parts.next() orelse "0";
            const v_float = std.fmt.parseFloat(f32, v_str) catch 0.0;
            try texcoords.append(allocator, .{ .x = u, .y = if (options.flip_uvs) 1.0 - v_float else v_float });
        } else if (std.mem.eql(u8, cmd, "usemtl")) {
            const mtl_name = parts.next() orelse "default";
            if (!std.mem.eql(u8, pending_mtl, mtl_name)) {
                allocator.free(pending_mtl);
                pending_mtl = try allocator.dupe(u8, mtl_name);
            }
        } else if (std.mem.eql(u8, cmd, "f")) {
            var face_verts: [16]u32 = undefined;
            var face_count: u32 = 0;

            while (parts.next()) |vert| {
                if (face_count >= 16) break;
                var parts2 = std.mem.splitScalar(u8, vert, '/');
                const pos_str = parts2.next() orelse continue;
                const pos_idx = std.fmt.parseInt(u32, pos_str, 10) catch continue;

                const uv_str = parts2.next() orelse "";
                const norm_str = parts2.next() orelse "";

                const uv_idx = if (uv_str.len > 0) std.fmt.parseInt(u32, uv_str, 10) catch 0 else 0;
                const norm_idx = if (norm_str.len > 0) std.fmt.parseInt(u32, norm_str, 10) catch 0 else 0;

                const pos = if (pos_idx > 0 and pos_idx <= positions.items.len)
                    positions.items[pos_idx - 1]
                else
                    math.Vec3.zero();

                const norm = if (norm_idx > 0 and norm_idx <= normals.items.len)
                    normals.items[norm_idx - 1]
                else
                    math.Vec3.up();

                const uv = if (uv_idx > 0 and uv_idx <= texcoords.items.len)
                    texcoords.items[uv_idx - 1]
                else
                    math.Vec2{ .x = 0, .y = 0 };

                try vertices.append(allocator, .{ .pos = pos, .norm = norm, .uv = uv });
                face_verts[face_count] = @intCast(vertices.items.len - 1);
                face_count += 1;
            }

            if (face_count < 3) continue;

            if (groups.items.len == 0 or !std.mem.eql(u8, groups.items[groups.items.len - 1].name, pending_mtl)) {
                try groups.append(allocator, .{
                    .name = try allocator.dupe(u8, pending_mtl),
                    .start_idx = vertices.items.len - face_count,
                    .vert_count = 0,
                    .indices = .{},
                });
            }

            var current_group = &groups.items[groups.items.len - 1];
            current_group.vert_count += face_count;
            if (face_count == 3) {
                try current_group.indices.appendSlice(allocator, face_verts[0..3]);
            } else {
                for (0..face_count - 2) |i| {
                    try current_group.indices.append(allocator, face_verts[0]);
                    try current_group.indices.append(allocator, face_verts[i + 1]);
                    try current_group.indices.append(allocator, face_verts[i + 2]);
                }
            }
        }
    }

    allocator.free(pending_mtl);

    if (vertices.items.len == 0) return Error.NoMeshesInModel;

    var min_p = vertices.items[0].pos;
    var max_p = vertices.items[0].pos;
    for (vertices.items) |v| {
        min_p.x = @min(min_p.x, v.pos.x);
        min_p.y = @min(min_p.y, v.pos.y);
        min_p.z = @min(min_p.z, v.pos.z);
        max_p.x = @max(max_p.x, v.pos.x);
        max_p.y = @max(max_p.y, v.pos.y);
        max_p.z = @max(max_p.z, v.pos.z);
    }

    var mesh_vertices = try allocator.alloc(Mesh.Vertex, vertices.items.len);
    // defer allocator.free(mesh_vertices);

    for (vertices.items, 0..) |v, i| {
        var p = v.pos;
        if (options.center) {
            const center = math.Vec3.scale(math.Vec3.add(min_p, max_p), 0.5);
            p = math.Vec3.sub(p, center);
        }
        if (options.scale != 1.0) {
            p = math.Vec3.scale(p, options.scale);
        }
        mesh_vertices[i] = .{
            .position = p,
            .normal = v.norm,
            .texcoord0 = .{ v.uv.x, v.uv.y },
        };
    }

    var indices_u16 = try allocator.alloc(u16, indices.items.len);
    // defer allocator.free(indices_u16);
    for (indices.items, 0..) |idx, i| {
        indices_u16[i] = @intCast(idx);
    }

    var submeshes_list: std.ArrayList(Submesh) = .{};
    defer submeshes_list.deinit(allocator);

    for (groups.items) |group| {
        const mtl_entry = materials.getEntry(group.name);
        const mtl_name = if (mtl_entry) |e| e.value_ptr.name else "default";
        const mtl_diffuse = if (mtl_entry) |e| e.value_ptr.diffuse else math.Vec4{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 };
        const mtl_texture = if (mtl_entry) |e| e.value_ptr.texture_path else &.{};

        const start_vert = group.start_idx;
        const end_vert = group.start_idx + group.vert_count;

        if (group.indices.items.len == 0) continue;

        var new_verts = try allocator.alloc(Mesh.Vertex, group.vert_count);
        defer allocator.free(new_verts);

        var remap: [4096]u32 = undefined;
        var new_vert_count: u32 = 0;
        for (start_vert..end_vert) |vi| {
            remap[vi] = new_vert_count;
            new_verts[new_vert_count] = mesh_vertices[vi];
            new_vert_count += 1;
        }

        var new_indices = try allocator.alloc(u16, group.indices.items.len);
        defer allocator.free(new_indices);
        var i: usize = 0;
        while (i < group.indices.items.len) : (i += 1) {
            new_indices[i] = @intCast(remap[group.indices.items[i]]);
        }

        const sub_mesh = try Mesh.initStatic(Mesh.Vertex, new_verts[0..new_vert_count], new_indices, .{});

        submeshes_list.append(allocator, .{
            .mesh = sub_mesh,
            .material = .{
                .name = try allocator.dupe(u8, mtl_name),
                .diffuse = mtl_diffuse,
                .texture_path = if (mtl_texture.len > 0) try allocator.dupe(u8, mtl_texture) else &.{},
            },
        }) catch continue;
    }

    defer allocator.free(mesh_vertices);

    if (submeshes_list.items.len == 0) return Error.NoMeshesInModel;

    const submeshes = try allocator.alloc(Submesh, submeshes_list.items.len);
    @memcpy(submeshes, submeshes_list.items);

    return LoadedModel{
        .submeshes = submeshes,
        .allocator = allocator,
    };
}

const MtlMaterial = struct {
    name: []u8,
    diffuse: math.Vec4,
    texture_path: []u8,
};

fn parseMtl(data: []const u8, base_dir: []const u8, allocator: std.mem.Allocator, materials: *std.StringHashMapUnmanaged(MtlMaterial)) void {
    var lines = std.mem.splitScalar(u8, data, '\n');
    var current_name: []u8 = &.{};
    var current_diffuse = math.Vec4{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 };
    var current_texture: []u8 = &.{};

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const cmd = parts.next() orelse continue;

        if (std.mem.eql(u8, cmd, "newmtl")) {
            if (current_name.len > 0) {
                materials.put(allocator, current_name, MtlMaterial{
                    .name = current_name,
                    .diffuse = current_diffuse,
                    .texture_path = current_texture,
                }) catch {};
            }
            const name_input = parts.next();
            const name_str: []const u8 = name_input orelse "default";
            current_name = allocator.dupe(u8, name_str) catch return;
            current_diffuse = .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 };
            current_texture = &[_]u8{};
        } else if (std.mem.eql(u8, cmd, "Kd")) {
            const r = std.fmt.parseFloat(f32, parts.next() orelse "0.8") catch 0.8;
            const g = std.fmt.parseFloat(f32, parts.next() orelse "0.8") catch 0.8;
            const b = std.fmt.parseFloat(f32, parts.next() orelse "0.8") catch 0.8;
            current_diffuse = .{ .x = r, .y = g, .z = b, .w = 1.0 };
        } else if (std.mem.eql(u8, cmd, "map_Kd")) {
            const tex_name = parts.next() orelse "";
            if (tex_name.len > 0) {
                if (base_dir.len > 0) {
                    current_texture = std.fs.path.join(allocator, &.{ base_dir, tex_name }) catch &[_]u8{};
                } else {
                    current_texture = allocator.dupe(u8, tex_name) catch &[_]u8{};
                }
            }
        }
    }

    if (current_name.len > 0) {
        materials.put(allocator, current_name, MtlMaterial{
            .name = current_name,
            .diffuse = current_diffuse,
            .texture_path = current_texture,
        }) catch {};
    }
}

pub fn loadGltf(allocator: std.mem.Allocator, path: [:0]const u8, options: LoadOptions) !LoadedModel {
    _ = options;
    ensureZmesh(allocator);
    const data = try zmesh.io.zcgltf.parseAndLoadFile(path);
    defer zmesh.io.zcgltf.freeData(data);

    if (data.meshes_count == 0) return Error.NoMeshesInModel;

    var submeshes_list: std.ArrayList(Submesh) = .{};
    errdefer {
        for (submeshes_list.items) |*s| s.mesh.deinit();
        submeshes_list.deinit(allocator);
    }

    var overall_min: math.Vec3 = undefined;
    var overall_max: math.Vec3 = undefined;
    var first_vert = true;
    var total_verts: u32 = 0;

    const base_dir = std.fs.path.dirname(path) orelse "";

    for (0..data.meshes_count) |mesh_idx| {
        const gltf_mesh = &data.meshes.?[mesh_idx];
        for (0..gltf_mesh.primitives_count) |prim_idx| {
            var indices: std.ArrayListUnmanaged(u32) = .{};
            var positions: std.ArrayListUnmanaged([3]f32) = .{};
            var normals: std.ArrayListUnmanaged([3]f32) = .{};
            var texcoords: std.ArrayListUnmanaged([2]f32) = .{};

            try zmesh.io.zcgltf.appendMeshPrimitive(
                allocator,
                data,
                @intCast(mesh_idx),
                @intCast(prim_idx),
                &indices,
                &positions,
                &normals,
                &texcoords,
                null,
            );

            defer {
                indices.deinit(allocator);
                positions.deinit(allocator);
                normals.deinit(allocator);
                texcoords.deinit(allocator);
            }

            if (positions.items.len == 0) continue;

            for (positions.items) |p| {
                if (first_vert) {
                    overall_min = .{ .x = p[0], .y = p[1], .z = p[2] };
                    overall_max = .{ .x = p[0], .y = p[1], .z = p[2] };
                    first_vert = false;
                } else {
                    overall_min.x = @min(overall_min.x, p[0]);
                    overall_min.y = @min(overall_min.y, p[1]);
                    overall_min.z = @min(overall_min.z, p[2]);
                    overall_max.x = @max(overall_max.x, p[0]);
                    overall_max.y = @max(overall_max.y, p[1]);
                    overall_max.z = @max(overall_max.z, p[2]);
                }
            }
            total_verts += @intCast(positions.items.len);

            var vertices = try allocator.alloc(Mesh.Vertex, positions.items.len);
            defer allocator.free(vertices);

            for (0..positions.items.len) |i| {
                vertices[i] = .{
                    .position = math.Vec3.fromArray(positions.items[i]),
                    .normal = if (normals.items.len > i) math.Vec3.fromArray(normals.items[i]) else math.Vec3.zero(),
                    .texcoord0 = if (texcoords.items.len > i) texcoords.items[i] else .{ 0, 0 },
                };
            }

            var indices_u16 = try allocator.alloc(u16, indices.items.len);
            defer allocator.free(indices_u16);
            for (0..indices.items.len) |i| {
                indices_u16[i] = @intCast(indices.items[i]);
            }

            const mesh = try Mesh.initStatic(Mesh.Vertex, vertices, indices_u16, .{});

            const prim = &gltf_mesh.primitives[prim_idx];
            const diffuse = extractGltfDiffuse(prim);
            const pbr_textures = extractGltfTextures(allocator, prim, base_dir) catch PbrTextures{};

            try submeshes_list.append(allocator, .{
                .mesh = mesh,
                .material = .{
                    .name = if (prim.material) |m| if (m.name) |n| try allocator.dupe(u8, std.mem.span(n)) else try allocator.dupe(u8, "gltf_material") else try allocator.dupe(u8, "gltf_default"),
                    .diffuse = diffuse,
                    .texture_path = pbr_textures.albedo_path,
                    .texture_data = pbr_textures.albedo_data,
                    .normal_texture_path = pbr_textures.normal_path,
                    .normal_texture_data = pbr_textures.normal_data,
                    .metallic_roughness_texture_path = pbr_textures.metallic_roughness_path,
                    .metallic_roughness_texture_data = pbr_textures.metallic_roughness_data,
                },
            });
        }
    }

    std.log.info("[MeshLoader] Loaded {} submeshes, {} total vertices", .{ submeshes_list.items.len, total_verts });

    return LoadedModel{
        .submeshes = try submeshes_list.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

fn extractGltfDiffuse(prim: *const zmesh.io.zcgltf.Primitive) math.Vec4 {
    if (prim.material) |mat| {
        if (mat.has_pbr_metallic_roughness != 0) {
            const pbr = mat.pbr_metallic_roughness;
            return .{
                .x = pbr.base_color_factor[0],
                .y = pbr.base_color_factor[1],
                .z = pbr.base_color_factor[2],
                .w = pbr.base_color_factor[3],
            };
        }
        if (mat.unlit != 0) {
            return .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 };
        }
    }
    return .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 };
}

const TextureResult = struct {
    path: []u8,
    embedded_data: ?[]u8,
};

const PbrTextures = struct {
    albedo_path: []u8 = "",
    albedo_data: ?[]u8 = null,
    metallic_roughness_path: []u8 = "",
    metallic_roughness_data: ?[]u8 = null,
    normal_path: []u8 = "",
    normal_data: ?[]u8 = null,
    occlusion_path: []u8 = "",
    occlusion_data: ?[]u8 = null,
};

fn extractGltfTextures(allocator: std.mem.Allocator, prim: *const zmesh.io.zcgltf.Primitive, base_dir: []const u8) error{OutOfMemory}!PbrTextures {
    var result = PbrTextures{};

    if (prim.material) |mat| {
        if (mat.normal_texture.texture) |tex| {
            if (tex.image) |image| {
                if (image.uri) |uri| {
                    const uri_str = std.mem.span(uri);
                    if (uri_str.len > 0 and !std.mem.startsWith(u8, uri_str, "data:")) {
                        if (base_dir.len > 0) {
                            result.normal_path = std.fs.path.join(allocator, &.{ base_dir, uri_str }) catch "";
                        } else {
                            result.normal_path = allocator.dupe(u8, uri_str) catch "";
                        }
                    } else if (image.buffer_view) |bv| {
                        const buf_data = bv.getData();
                        if (buf_data) |ptr| {
                            result.normal_data = allocator.alloc(u8, bv.size) catch null;
                            if (result.normal_data) |data| {
                                @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                            }
                        }
                    }
                }
            }
        }
        if (mat.occlusion_texture.texture) |tex| {
            if (tex.image) |image| {
                if (image.uri) |uri| {
                    const uri_str = std.mem.span(uri);
                    if (uri_str.len > 0 and !std.mem.startsWith(u8, uri_str, "data:")) {
                        if (base_dir.len > 0) {
                            result.occlusion_path = std.fs.path.join(allocator, &.{ base_dir, uri_str }) catch "";
                        } else {
                            result.occlusion_path = allocator.dupe(u8, uri_str) catch "";
                        }
                    } else if (image.buffer_view) |bv| {
                        const buf_data = bv.getData();
                        if (buf_data) |ptr| {
                            result.occlusion_data = allocator.alloc(u8, bv.size) catch null;
                            if (result.occlusion_data) |data| {
                                @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                            }
                        }
                    }
                }
            }
        }
        if (mat.has_pbr_metallic_roughness != 0) {
            const pbr = mat.pbr_metallic_roughness;
            if (pbr.base_color_texture.texture) |tex| {
                if (tex.image) |image| {
                    if (image.uri) |uri| {
                        const uri_str = std.mem.span(uri);
                        if (uri_str.len > 0 and !std.mem.startsWith(u8, uri_str, "data:")) {
                            if (base_dir.len > 0) {
                                result.albedo_path = std.fs.path.join(allocator, &.{ base_dir, uri_str }) catch "";
                            } else {
                                result.albedo_path = allocator.dupe(u8, uri_str) catch "";
                            }
                        } else if (image.buffer_view) |bv| {
                            const buf_data = bv.getData();
                            if (buf_data) |ptr| {
                                result.albedo_data = allocator.alloc(u8, bv.size) catch null;
                                if (result.albedo_data) |data| {
                                    @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                                }
                            }
                        }
                    } else if (image.buffer_view) |bv| {
                        const buf_data = bv.getData();
                        if (buf_data) |ptr| {
                            result.albedo_data = allocator.alloc(u8, bv.size) catch null;
                            if (result.albedo_data) |data| {
                                @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                            }
                        }
                    }
                }
            }
            if (pbr.metallic_roughness_texture.texture) |tex| {
                if (tex.image) |image| {
                    if (image.uri) |uri| {
                        const uri_str = std.mem.span(uri);
                        if (uri_str.len > 0 and !std.mem.startsWith(u8, uri_str, "data:")) {
                            if (base_dir.len > 0) {
                                result.metallic_roughness_path = std.fs.path.join(allocator, &.{ base_dir, uri_str }) catch "";
                            } else {
                                result.metallic_roughness_path = allocator.dupe(u8, uri_str) catch "";
                            }
                        } else if (image.buffer_view) |bv| {
                            const buf_data = bv.getData();
                            if (buf_data) |ptr| {
                                result.metallic_roughness_data = allocator.alloc(u8, bv.size) catch null;
                                if (result.metallic_roughness_data) |data| {
                                    @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                                }
                            }
                        }
                    } else if (image.buffer_view) |bv| {
                        const buf_data = bv.getData();
                        if (buf_data) |ptr| {
                            result.metallic_roughness_data = allocator.alloc(u8, bv.size) catch null;
                            if (result.metallic_roughness_data) |data| {
                                @memcpy(data, @as([*]const u8, @ptrCast(ptr))[0..bv.size]);
                            }
                        }
                    }
                }
            }
        }
    }
    return result;
}
