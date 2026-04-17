const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const stb = @import("stb");

pub const EnvMap = struct {
    irradiance_map: bgfx.TextureHandle,
    prefiltered_map: bgfx.TextureHandle,
    brdf_lut: bgfx.TextureHandle,
    intensity: f32 = 1.0,
    valid: bool = false,
};

pub const Environment = struct {
    allocator: std.mem.Allocator,
    env_map: EnvMap,

    pub fn init(allocator: std.mem.Allocator, hdr_path: [:0]const u8) !*Environment {
        const self = try allocator.create(Environment);
        errdefer allocator.destroy(self);

        var hdr_img = stb.image.HdrImage.init(hdr_path) catch {
            std.log.err("[env_map] Failed to load HDR: {s}", .{hdr_path});
            return error.LoadFailed;
        };
        defer hdr_img.deinit();

        std.log.info("[env_map] Loaded HDR: {}x{}", .{ hdr_img.width, hdr_img.height });

        const env_data = try convertHdrToRgba32f(allocator, hdr_img.width, hdr_img.height, hdr_img.data);
        errdefer allocator.free(env_data);

        std.log.info("[env_map] Computing irradiance map...", .{});

        const irradiance = try convolveIrradiance(allocator, env_data, hdr_img.width, hdr_img.height);
        errdefer allocator.free(irradiance);

        std.log.info("[env_map] Computing prefiltered map...", .{});

        const prefiltered = try convolvePrefiltered(allocator, env_data, hdr_img.width, hdr_img.height);
        errdefer allocator.free(prefiltered);

        std.log.info("[env_map] Computing BRDF LUT...", .{});

        const brdf_lut_data = try generateBrdfLutData(allocator);
        defer allocator.free(brdf_lut_data);

        std.log.info("[env_map] Uploading textures...", .{});

        const env_map: EnvMap = .{
            .irradiance_map = uploadTexture(irradiance, 256, 128),
            .prefiltered_map = uploadTexture(prefiltered, 512, 256),
            .brdf_lut = uploadBrdfLut(brdf_lut_data),
            .intensity = 0.3,
            .valid = true,
        };

        self.* = .{
            .allocator = allocator,
            .env_map = env_map,
        };

        return self;
    }

    pub fn deinit(self: *Environment) void {
        if (self.env_map.valid) {
            bgfx.destroyTexture(self.env_map.irradiance_map);
            bgfx.destroyTexture(self.env_map.prefiltered_map);
            bgfx.destroyTexture(self.env_map.brdf_lut);
        }
        self.allocator.destroy(self);
    }
};

fn uploadTexture(data: []f32, width: u32, height: u32) bgfx.TextureHandle {
    const mem = bgfx.copy(@ptrCast(data.ptr), @intCast(data.len * @sizeOf(f32)));
    return bgfx.createTexture2D(
        @intCast(width),
        @intCast(height),
        false,
        1,
        .RGBA32F,
        bgfx.TextureFlags_None,
        mem,
        0,
    );
}

fn uploadBrdfLut(data: []f32) bgfx.TextureHandle {
    const size: u32 = 256;
    const mem = bgfx.copy(@ptrCast(data.ptr), @intCast(data.len * @sizeOf(f32)));
    return bgfx.createTexture2D(size, size, false, 1, .RGBA32F, bgfx.TextureFlags_None, mem, 0);
}

fn convertHdrToRgba32f(allocator: std.mem.Allocator, width: u32, height: u32, data: [*]f32) ![]f32 {
    const pixel_count = width * height;
    const rgba = try allocator.alloc(f32, pixel_count * 4);

    var i: u32 = 0;
    while (i < pixel_count) : (i += 1) {
        rgba[i * 4 + 0] = data[i * 3 + 0];
        rgba[i * 4 + 1] = data[i * 3 + 1];
        rgba[i * 4 + 2] = data[i * 3 + 2];
        rgba[i * 4 + 3] = 1.0;
    }

    return rgba;
}

fn sampleEnv(data: []const f32, width: u32, height: u32, theta: f32, phi: f32) [3]f32 {
    const u = phi / (2.0 * std.math.pi);
    const v = theta / std.math.pi;

    const x = @mod(@as(i32, @intFromFloat(u * @as(f32, @floatFromInt(width)))), @as(i32, @intCast(width)));
    const y = @mod(@as(i32, @intFromFloat(v * @as(f32, @floatFromInt(height)))), @as(i32, @intCast(height)));

    const idx = (@as(usize, @intCast(y)) * width + @as(usize, @intCast(x))) * 4;

    return .{ data[idx + 0], data[idx + 1], data[idx + 2] };
}

var rng_state: u64 = 12345;

fn randomFloat() f32 {
    rng_state = rng_state *% 1103515245 +% 12345;
    const value = (rng_state >> 16) & 0x7FFF;
    return @as(f32, @floatFromInt(value)) / 32768.0;
}

fn convolveIrradiance(allocator: std.mem.Allocator, env_data: []const f32, env_width: u32, env_height: u32) ![]f32 {
    const irr_width: u32 = 256;
    const irr_height: u32 = 128;
    const pixel_count = irr_width * irr_height;
    const irradiance = try allocator.alloc(f32, pixel_count * 4);

    const sample_count: u32 = 256;
    const norm_factor = 1.0 / (@as(f32, @floatFromInt(sample_count)) * std.math.pi);

    var y: u32 = 0;
    while (y < irr_height) : (y += 1) {
        var x: u32 = 0;
        while (x < irr_width) : (x += 1) {
            const theta = std.math.pi * (@as(f32, @floatFromInt(y)) + 0.5) / @as(f32, @floatFromInt(irr_height));
            const phi = 2.0 * std.math.pi * (@as(f32, @floatFromInt(x)) + 0.5) / @as(f32, @floatFromInt(irr_width));

            const dir_x = @sin(theta) * @cos(phi);
            const dir_y = @sin(theta) * @sin(phi);
            const dir_z = @cos(theta);

            var color_x: f32 = 0.0;
            var color_y: f32 = 0.0;
            var color_z: f32 = 0.0;

            var s: u32 = 0;
            while (s < sample_count) : (s += 1) {
                const r1 = randomFloat();
                const r2 = randomFloat();

                const sample_theta = std.math.acos(@sqrt(1.0 - r2));
                const sample_phi = 2.0 * std.math.pi * r1;

                const env_sample = sampleEnv(env_data, env_width, env_height, sample_theta, sample_phi);

                const n_x = @sin(sample_theta) * @cos(sample_phi);
                const n_y = @sin(sample_theta) * @sin(sample_phi);
                const n_z = @cos(sample_theta);

                const n_dot_l = @max(n_x * dir_x + n_y * dir_y + n_z * dir_z, 0.0);
                const weight = n_dot_l * @sin(sample_theta);

                color_x += env_sample[0] * weight;
                color_y += env_sample[1] * weight;
                color_z += env_sample[2] * weight;
            }

            const idx = (y * irr_width + x) * 4;
            irradiance[idx + 0] = color_x * norm_factor;
            irradiance[idx + 1] = color_y * norm_factor;
            irradiance[idx + 2] = color_z * norm_factor;
            irradiance[idx + 3] = 1.0;
        }
    }

    return irradiance;
}

fn convolvePrefiltered(allocator: std.mem.Allocator, env_data: []const f32, env_width: u32, env_height: u32) ![]f32 {
    const pf_width: u32 = 512;
    const pf_height: u32 = 256;
    const pixel_count = pf_width * pf_height;
    const prefiltered = try allocator.alloc(f32, pixel_count * 4);

    const sample_count: u32 = 128;

    var y: u32 = 0;
    while (y < pf_height) : (y += 1) {
        var x: u32 = 0;
        while (x < pf_width) : (x += 1) {
            const theta = std.math.pi * (@as(f32, @floatFromInt(y)) + 0.5) / @as(f32, @floatFromInt(pf_height));
            const phi = 2.0 * std.math.pi * (@as(f32, @floatFromInt(x)) + 0.5) / @as(f32, @floatFromInt(pf_width));

            const R_x = @sin(theta) * @cos(phi);
            const R_y = @sin(theta) * @sin(phi);
            const R_z = @cos(theta);

            const roughness = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(pf_height));
            const a = roughness * roughness;

            var color_x: f32 = 0.0;
            var color_y: f32 = 0.0;
            var color_z: f32 = 0.0;

            var s: u32 = 0;
            while (s < sample_count) : (s += 1) {
                const r1 = randomFloat();
                const r2 = randomFloat();

                const sample_theta = std.math.acos(@sqrt(1.0 - r2));
                const sample_phi = 2.0 * std.math.pi * r1 * r2;

                const H_x = @sin(sample_theta) * @cos(sample_phi);
                const H_y = @sin(sample_theta) * @sin(sample_phi);
                const H_z = @cos(sample_theta);

                const l_dot_h = R_x * H_x + R_y * H_y + R_z * H_z;
                if (l_dot_h > 0.0) {
                    const L_x = 2.0 * l_dot_h * H_x - R_x;
                    const L_y = 2.0 * l_dot_h * H_y - R_y;
                    const L_z = 2.0 * l_dot_h * H_z - R_z;

                    const len_L = @sqrt(L_x * L_x + L_y * L_y + L_z * L_z);
                    if (len_L > 0.0001) {
                        const nl_x = L_x / len_L;
                        const nl_y = L_y / len_L;
                        const nl_z = L_z / len_L;

                        if (nl_z > 0.0) {
                            const env_sample = sampleEnv(env_data, env_width, env_height, std.math.acos(@max(nl_z, 0.0)), std.math.atan2(nl_y, nl_x));

                            const n_dot_h = @max(H_z, 0.0);
                            const a2 = a * a;
                            const ndh2 = n_dot_h * n_dot_h;
                            const denom = ndh2 * (a2 - 1.0) + 1.0;
                            const D = a2 / (std.math.pi * denom * denom + 0.0001);

                            const pdf = D * n_dot_h / (4.0 * l_dot_h + 0.0001);
                            const weight = l_dot_h * pdf * @sin(sample_theta);

                            color_x += env_sample[0] * weight;
                            color_y += env_sample[1] * weight;
                            color_z += env_sample[2] * weight;
                        }
                    }
                }
            }

            const idx = (y * pf_width + x) * 4;
            prefiltered[idx + 0] = color_x;
            prefiltered[idx + 1] = color_y;
            prefiltered[idx + 2] = color_z;
            prefiltered[idx + 3] = 1.0;
        }
    }

    return prefiltered;
}

fn generateBrdfLutData(allocator: std.mem.Allocator) ![]f32 {
    const size: u32 = 256;
    const data = try allocator.alloc(f32, size * size * 4);

    var y: u32 = 0;
    while (y < size) : (y += 1) {
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            const NdotV = (@as(f32, @floatFromInt(x)) + 0.5) / @as(f32, @floatFromInt(size));
            const roughness = (@as(f32, @floatFromInt(y)) + 0.5) / @as(f32, @floatFromInt(size));

            const a = roughness * roughness;
            const k = a / 2.0;

            var r: f32 = 0.0;
            var t: f32 = 0.0;

            const sample_count: u32 = 256;
            var s: u32 = 0;
            while (s < sample_count) : (s += 1) {
                const r1 = (@as(f32, @floatFromInt(s)) + 0.5) / @as(f32, @floatFromInt(sample_count));
                const r2 = randomFloat();

                const cos_theta = @sqrt((1.0 - r1) / (1.0 - a * r1 + 0.0001));
                const sin_theta = @sqrt(@max(1.0 - cos_theta * cos_theta, 0.0));
                const phi = 2.0 * std.math.pi * r2;

                const h_x = sin_theta * @cos(phi);
                const h_z = cos_theta;

                const v_x = @sqrt(@max(1.0 - NdotV * NdotV, 0.0));
                const v_z = NdotV;

                const v_dot_h = v_x * h_x + v_z * h_z;
                const l_z = 2.0 * v_dot_h * h_z - v_z;

                const n_dot_l = @max(l_z, 0.0);
                const n_dot_h = @max(h_z, 0.0);

                if (n_dot_l > 0.0 and v_dot_h > 0.0) {
                    const n_dot_v = NdotV;
                    const g1_l = n_dot_l / (n_dot_l * (1.0 - k) + k);
                    const g1_v = n_dot_v / (n_dot_v * (1.0 - k) + k);
                    const g = g1_l * g1_v;

                    const gv = g * v_dot_h / (@max(n_dot_h * n_dot_v, 0.0001));
                    const gc = gv / (1.0 - g + 0.0001);

                    r += gc;
                    t += gc * n_dot_l;
                }
            }

            r /= @as(f32, @floatFromInt(sample_count));
            t /= @as(f32, @floatFromInt(sample_count));

            const idx = (y * size + x) * 4;
            data[idx + 0] = r;
            data[idx + 1] = t;
            data[idx + 2] = 0.0;
            data[idx + 3] = 1.0;
        }
    }

    return data;
}
