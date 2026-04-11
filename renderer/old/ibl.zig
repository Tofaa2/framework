const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const resources = @import("resources_new.zig");

pub const IBLRenderer = struct {
    res: *resources.ResourcePool,
    brdf_lut: resources.TextureHandle,
    irradiance_cubemap: resources.TextureHandle,
    prefiltered_cubemap: resources.TextureHandle,
    irradiance_uniform: bgfx.UniformHandle,
    prefiltered_uniform: bgfx.UniformHandle,
    brdf_lut_uniform: bgfx.UniformHandle,

    pub fn init(_: std.mem.Allocator, res: *resources.ResourcePool) !IBLRenderer {
        return .{
            .res = res,
            .brdf_lut = try res.createBRDFLUT(),
            .irradiance_cubemap = .invalid,
            .prefiltered_cubemap = .invalid,
            .irradiance_uniform = bgfx.createUniform("s_irradiance", .Sampler, 1),
            .prefiltered_uniform = bgfx.createUniform("s_prefiltered", .Sampler, 1),
            .brdf_lut_uniform = bgfx.createUniform("s_brdfLUT", .Sampler, 1),
        };
    }

    pub fn deinit(self: *IBLRenderer) void {
        bgfx.destroyUniform(self.irradiance_uniform);
        bgfx.destroyUniform(self.prefiltered_uniform);
        bgfx.destroyUniform(self.brdf_lut_uniform);
    }

    pub fn bind(self: *const IBLRenderer) void {
        if (resources.isValid(self.irradiance_cubemap)) {
            const tex = self.res.getTexture(self.irradiance_cubemap);
            if (tex) |t| {
                _ = bgfx.setTexture(1, self.irradiance_uniform, t.handle, bgfx.TextureFlags_Sample | bgfx.TextureFlags_U_Sample | bgfx.TextureFlags_V_Sample | bgfx.TextureFlags_W_Sample);
            }
        }
        if (resources.isValid(self.prefiltered_cubemap)) {
            const tex = self.res.getTexture(self.prefiltered_cubemap);
            if (tex) |t| {
                _ = bgfx.setTexture(2, self.prefiltered_uniform, t.handle, bgfx.TextureFlags_Sample | bgfx.TextureFlags_U_Sample | bgfx.TextureFlags_V_Sample | bgfx.TextureFlags_W_Sample | bgfx.TextureFlags_Srgb);
            }
        }
        if (resources.isValid(self.brdf_lut)) {
            const tex = self.res.getTexture(self.brdf_lut);
            if (tex) |t| {
                _ = bgfx.setTexture(3, self.brdf_lut_uniform, t.handle, bgfx.TextureFlags_None);
            }
        }
    }

    pub fn loadFromHDR(self: *IBLRenderer, allocator: std.mem.Allocator, data: []const f32, width: u32, height: u32) !void {
        const cube_size: u16 = 256;
        const irradiance_size: u16 = 32;
        const prefiltered_size: u16 = 256;

        const faces = try generateCubemapFromEquirectangular(allocator, data, width, height, cube_size);
        defer {
            for (faces) |face| allocator.free(face);
        }

        const irradiance_faces = try generateIrradianceCubemap(allocator, &faces, cube_size, irradiance_size);
        defer {
            for (irradiance_faces) |face| allocator.free(face);
        }

        self.irradiance_cubemap = try self.res.createCubemapFromFaces(allocator, irradiance_faces, irradiance_size);

        const prefiltered_faces = try generatePrefilteredCubemap(allocator, &faces, cube_size, prefiltered_size);
        defer {
            for (prefiltered_faces) |face| allocator.free(face);
        }

        self.prefiltered_cubemap = try self.res.createPrefilteredCubemapFromFaces(allocator, &prefiltered_faces, prefiltered_size, 1);

        std.debug.print("IBL: Generated irradiance cubemap ({}x{}), prefiltered cubemap ({}x{})\n", .{ irradiance_size, irradiance_size, prefiltered_size, prefiltered_size });
    }
};

fn generateCubemapFromEquirectangular(allocator: std.mem.Allocator, data: []const f32, src_width: u32, src_height: u32, cube_size: u16) ![6][]f32 {
    const face_count: u32 = 6;
    const face_size = @as(u32, cube_size) * @as(u32, cube_size) * 3;
    var faces: [face_count][]f32 = undefined;

    for (0..6) |f| {
        faces[f] = try allocator.alloc(f32, face_size);
        @memset(faces[f], 0);
    }

    const face_directions = [6][3]f32{
        .{ 1.0, 0.0, 0.0 }, // +X
        .{ -1.0, 0.0, 0.0 }, // -X
        .{ 0.0, 1.0, 0.0 }, // +Y
        .{ 0.0, -1.0, 0.0 }, // -Y
        .{ 0.0, 0.0, 1.0 }, // +Z
        .{ 0.0, 0.0, -1.0 }, // -Z
    };

    const face_ups = [6][3]f32{
        .{ 0.0, -1.0, 0.0 }, // +X
        .{ 0.0, -1.0, 0.0 }, // -X
        .{ 0.0, 0.0, 1.0 }, // +Y
        .{ 0.0, 0.0, -1.0 }, // -Y
        .{ 0.0, -1.0, 0.0 }, // +Z
        .{ 0.0, -1.0, 0.0 }, // -Z
    };

    for (0..6) |f| {
        const fd = face_directions[f];
        const fu = face_ups[f];

        const right = normalize(cross(fd, fu));
        const up = normalize(cross(right, fd));

        var vy: u16 = 0;
        while (vy < cube_size) : (vy += 1) {
            var vx: u16 = 0;
            while (vx < cube_size) : (vx += 1) {
                const u = (@as(f32, @floatFromInt(vx)) + 0.5) / @as(f32, @floatFromInt(cube_size)) * 2.0 - 1.0;
                const v = (@as(f32, @floatFromInt(vy)) + 0.5) / @as(f32, @floatFromInt(cube_size)) * 2.0 - 1.0;

                const dir = normalize([3]f32{
                    fd[0] + u * right[0] + v * up[0],
                    fd[1] + u * right[1] + v * up[1],
                    fd[2] + u * right[2] + v * up[2],
                });

                const color = sampleEquirectangular(data, src_width, src_height, dir);

                const idx = (@as(u32, vy) * @as(u32, cube_size) + @as(u32, vx)) * 3;
                faces[f][idx + 0] = color[0];
                faces[f][idx + 1] = color[1];
                faces[f][idx + 2] = color[2];
            }
        }
    }

    return faces;
}

fn generateIrradianceCubemap(allocator: std.mem.Allocator, src_faces: *const [6][]f32, src_size: u16, dest_size: u16) ![6][]f32 {
    const face_size = @as(u32, dest_size) * @as(u32, dest_size) * 3;
    var faces: [6][]f32 = undefined;

    for (0..6) |f| {
        faces[f] = try allocator.alloc(f32, face_size);
        @memset(faces[f], 0);
    }

    const face_directions = [6][3]f32{
        .{ 1.0, 0.0, 0.0 }, // +X
        .{ -1.0, 0.0, 0.0 }, // -X
        .{ 0.0, 1.0, 0.0 }, // +Y
        .{ 0.0, -1.0, 0.0 }, // -Y
        .{ 0.0, 0.0, 1.0 }, // +Z
        .{ 0.0, 0.0, -1.0 }, // -Z
    };

    const face_ups = [6][3]f32{
        .{ 0.0, -1.0, 0.0 }, // +X
        .{ 0.0, -1.0, 0.0 }, // -X
        .{ 0.0, 0.0, 1.0 }, // +Y
        .{ 0.0, 0.0, -1.0 }, // -Y
        .{ 0.0, -1.0, 0.0 }, // +Z
        .{ 0.0, -1.0, 0.0 }, // -Z
    };

    const sample_count: u32 = 512;

    for (0..6) |f| {
        const fd = face_directions[f];
        const fu = face_ups[f];

        const right = normalize(cross(fd, fu));
        const up = normalize(cross(right, fd));

        var vy: u16 = 0;
        while (vy < dest_size) : (vy += 1) {
            var vx: u16 = 0;
            while (vx < dest_size) : (vx += 1) {
                const u = (@as(f32, @floatFromInt(vx)) + 0.5) / @as(f32, @floatFromInt(dest_size)) * 2.0 - 1.0;
                const v = (@as(f32, @floatFromInt(vy)) + 0.5) / @as(f32, @floatFromInt(dest_size)) * 2.0 - 1.0;

                const N = normalize([3]f32{
                    fd[0] + u * right[0] + v * up[0],
                    fd[1] + u * right[1] + v * up[1],
                    fd[2] + u * right[2] + v * up[2],
                });

                var irradiance = [3]f32{ 0.0, 0.0, 0.0 };

                var si: u32 = 0;
                while (si < sample_count) : (si += 1) {
                    const xi1 = (@as(f32, @floatFromInt(si)) + radicalInverse(si)) / @as(f32, @floatFromInt(sample_count));
                    const xi2 = radicalInverse(si * 2);

                    const phi = 2.0 * std.math.pi * xi1;
                    const cos_theta = @sqrt(1.0 - xi2);
                    const sin_theta = @sqrt(xi2);

                    const L = [3]f32{
                        @cos(phi) * sin_theta,
                        @sin(phi) * sin_theta,
                        cos_theta,
                    };

                    const local_x = normalize([3]f32{ -N[2], 0.0, N[0] });
                    const local_y = cross(N, local_x);

                    const sample_dir = normalize([3]f32{
                        N[0] + local_x[0] * L[0] + local_y[0] * L[1],
                        N[1] + local_x[1] * L[0] + local_y[1] * L[1],
                        N[2] + local_x[2] * L[0] + local_y[2] * L[1],
                    });

                    const NdotL = sample_dir[1];
                    if (NdotL > 0.0) {
                        const env_color = sampleCubemap(src_faces, src_size, sample_dir);
                        irradiance[0] += env_color[0] * NdotL;
                        irradiance[1] += env_color[1] * NdotL;
                        irradiance[2] += env_color[2] * NdotL;
                    }
                }

                const scale = 2.0 * std.math.pi / @as(f32, @floatFromInt(sample_count));
                irradiance[0] *= scale;
                irradiance[1] *= scale;
                irradiance[2] *= scale;

                const idx = (@as(u32, vy) * @as(u32, dest_size) + @as(u32, vx)) * 3;
                faces[f][idx + 0] = irradiance[0];
                faces[f][idx + 1] = irradiance[1];
                faces[f][idx + 2] = irradiance[2];
            }
        }
    }

    return faces;
}

fn generatePrefilteredCubemap(allocator: std.mem.Allocator, src_faces: *const [6][]f32, src_size: u16, dest_size: u16) ![6][]f32 {
    const roughness: f32 = 0.5;
    const sample_count: u32 = 1024;

    const face_directions = [6][3]f32{
        .{ 1.0, 0.0, 0.0 }, // +X
        .{ -1.0, 0.0, 0.0 }, // -X
        .{ 0.0, 1.0, 0.0 }, // +Y
        .{ 0.0, -1.0, 0.0 }, // -Y
        .{ 0.0, 0.0, 1.0 }, // +Z
        .{ 0.0, 0.0, -1.0 }, // -Z
    };

    const face_ups = [6][3]f32{
        .{ 0.0, -1.0, 0.0 }, // +X
        .{ 0.0, -1.0, 0.0 }, // -X
        .{ 0.0, 0.0, 1.0 }, // +Y
        .{ 0.0, 0.0, -1.0 }, // -Y
        .{ 0.0, -1.0, 0.0 }, // +Z
        .{ 0.0, -1.0, 0.0 }, // -Z
    };

    var faces: [6][]f32 = undefined;

    for (0..6) |f| {
        const fd = face_directions[f];
        const fu = face_ups[f];

        const right = normalize(cross(fd, fu));
        const up = normalize(cross(right, fd));

        faces[f] = try allocator.alloc(f32, @as(u32, dest_size) * @as(u32, dest_size) * 3);
        @memset(faces[f], 0);

        var vy: u16 = 0;
        while (vy < dest_size) : (vy += 1) {
            var vx: u16 = 0;
            while (vx < dest_size) : (vx += 1) {
                const u = (@as(f32, @floatFromInt(vx)) + 0.5) / @as(f32, @floatFromInt(dest_size)) * 2.0 - 1.0;
                const v = (@as(f32, @floatFromInt(vy)) + 0.5) / @as(f32, @floatFromInt(dest_size)) * 2.0 - 1.0;

                const N = normalize([3]f32{
                    fd[0] + u * right[0] + v * up[0],
                    fd[1] + u * right[1] + v * up[1],
                    fd[2] + u * right[2] + v * up[2],
                });

                var color = [3]f32{ 0.0, 0.0, 0.0 };
                var total_weight: f32 = 0.0;

                var si: u32 = 0;
                while (si < sample_count) : (si += 1) {
                    const xi1 = (@as(f32, @floatFromInt(si)) + radicalInverse(si)) / @as(f32, @floatFromInt(sample_count));
                    const xi2 = radicalInverse(si * 2);

                    const phi = 2.0 * std.math.pi * xi1;
                    const cos_theta = @sqrt((1.0 - xi2) / (1.0 + roughness * roughness * roughness * xi2));
                    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

                    const H = [3]f32{
                        @cos(phi) * sin_theta,
                        @sin(phi) * sin_theta,
                        cos_theta,
                    };

                    const local_x = normalize([3]f32{ -N[2], 0.0, N[0] });
                    const local_y = cross(N, local_x);

                    const L = normalize([3]f32{
                        local_x[0] * H[0] + local_y[0] * H[1] + N[0] * H[2],
                        local_x[1] * H[0] + local_y[1] * H[1] + N[1] * H[2],
                        local_x[2] * H[0] + local_y[2] * H[1] + N[2] * H[2],
                    });

                    const NdotL = @max(L[1], 0.0);
                    const NdotH = @max(H[2], 0.0);
                    const VdotH = @max(dot([3]f32{ -N[0], N[1], -N[2] }, H), 0.0);

                    if (NdotL > 0.0) {
                        const D = D_GGX(NdotH, roughness);
                        const G = G_Smith(@max(N[1], 0.0), NdotL, roughness);
                        const pdf = D * NdotH / (4.0 * VdotH + 0.0001);

                        const weight = NdotL * G * VdotH / (NdotH * pdf + 0.0001);

                        const env_color = sampleCubemap(src_faces, src_size, L);
                        color[0] += env_color[0] * weight;
                        color[1] += env_color[1] * weight;
                        color[2] += env_color[2] * weight;
                        total_weight += weight;
                    }
                }

                if (total_weight > 0.0) {
                    color[0] /= total_weight;
                    color[1] /= total_weight;
                    color[2] /= total_weight;
                }

                const idx = (@as(u32, vy) * @as(u32, dest_size) + @as(u32, vx)) * 3;
                faces[f][idx + 0] = color[0];
                faces[f][idx + 1] = color[1];
                faces[f][idx + 2] = color[2];
            }
        }
    }

    return faces;
}

fn sampleEquirectangular(data: []const f32, width: u32, height: u32, dir: [3]f32) [3]f32 {
    const phi = std.math.atan2(dir[2], dir[0]);
    const theta = std.math.acos(dir[1]);

    const u = (phi / (2.0 * std.math.pi) + 0.5);
    const v = theta / std.math.pi;

    const sx = @min(@max(u * @as(f32, @floatFromInt(width)), 0.0), @as(f32, @floatFromInt(width - 1)));
    const sy = @min(@max(v * @as(f32, @floatFromInt(height)), 0.0), @as(f32, @floatFromInt(height - 1)));

    const x0 = @as(u32, @intFromFloat(sx));
    const y0 = @as(u32, @intFromFloat(sy));
    const x1 = @min(x0 + 1, width - 1);
    const y1 = @min(y0 + 1, height - 1);

    const fx = sx - @as(f32, @floatFromInt(x0));
    const fy = sy - @as(f32, @floatFromInt(y0));

    const idx00 = (y0 * width + x0) * 3;
    const idx10 = (y0 * width + x1) * 3;
    const idx01 = (y1 * width + x0) * 3;
    const idx11 = (y1 * width + x1) * 3;

    const c00 = [3]f32{ data[idx00], data[idx00 + 1], data[idx00 + 2] };
    const c10 = [3]f32{ data[idx10], data[idx10 + 1], data[idx10 + 2] };
    const c01 = [3]f32{ data[idx01], data[idx01 + 1], data[idx01 + 2] };
    const c11 = [3]f32{ data[idx11], data[idx11 + 1], data[idx11 + 2] };

    const c0 = lerp(c00, c10, fx);
    const c1 = lerp(c01, c11, fx);

    return lerp(c0, c1, fy);
}

fn sampleCubemap(faces: *const [6][]f32, size: u16, dir: [3]f32) [3]f32 {
    const abs_x = @abs(dir[0]);
    const abs_y = @abs(dir[1]);
    const abs_z = @abs(dir[2]);

    var face: u32 = 0;
    var u: f32 = 0;
    var v: f32 = 0;

    if (abs_x >= abs_y and abs_x >= abs_z) {
        if (dir[0] > 0) {
            face = 0;
            u = -dir[2] / abs_x;
            v = -dir[1] / abs_x;
        } else {
            face = 1;
            u = dir[2] / abs_x;
            v = -dir[1] / abs_x;
        }
    } else if (abs_y >= abs_x and abs_y >= abs_z) {
        if (dir[1] > 0) {
            face = 2;
            u = dir[0] / abs_y;
            v = dir[2] / abs_y;
        } else {
            face = 3;
            u = dir[0] / abs_y;
            v = -dir[2] / abs_y;
        }
    } else {
        if (dir[2] > 0) {
            face = 4;
            u = dir[0] / abs_z;
            v = -dir[1] / abs_z;
        } else {
            face = 5;
            u = -dir[0] / abs_z;
            v = -dir[1] / abs_z;
        }
    }

    u = (u + 1.0) * 0.5 * @as(f32, @floatFromInt(size));
    v = (v + 1.0) * 0.5 * @as(f32, @floatFromInt(size));

    const clamped_u = @max(0.0, @min(u, @as(f32, @floatFromInt(size - 1))));
    const clamped_v = @max(0.0, @min(v, @as(f32, @floatFromInt(size - 1))));
    const x: u32 = @intFromFloat(clamped_u);
    const y: u32 = @intFromFloat(clamped_v);

    const idx = (y * @as(u32, size) + x) * 3;
    return [3]f32{ faces[face][idx], faces[face][idx + 1], faces[face][idx + 2] };
}

fn normalize(v: [3]f32) [3]f32 {
    const len = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len < 0.0001) return .{ 0.0, 0.0, 0.0 };
    return [3]f32{ v[0] / len, v[1] / len, v[2] / len };
}

fn cross(a: [3]f32, b: [3]f32) [3]f32 {
    return [3]f32{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn dot(a: [3]f32, b: [3]f32) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

fn lerp(a: [3]f32, b: [3]f32, t: f32) [3]f32 {
    return [3]f32{
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    };
}

fn radicalInverse(i: u32) f32 {
    var bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);
    return @as(f32, @floatFromInt(bits)) / 4294967296.0;
}

fn D_GGX(NdotH: f32, roughness: f32) f32 {
    const a = roughness * roughness;
    const a2 = a * a;
    const d = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (std.math.pi * d * d);
}

fn G_Smith(NdotV: f32, NdotL: f32, roughness: f32) f32 {
    const r = roughness + 1.0;
    const k = (r * r) / 8.0;
    const ggx_v = NdotV / (NdotV * (1.0 - k) + k);
    const ggx_l = NdotL / (NdotL * (1.0 - k) + k);
    return ggx_v * ggx_l;
}
