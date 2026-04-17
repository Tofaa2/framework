/// Material descriptor union.
/// Each variant describes the visual properties of a surface.
/// To draw with a material, call bind() which uploads uniforms to bgfx.
const std = @import("std");
const math = @import("math");
const bgfx = @import("bgfx").bgfx;
const Texture = @import("Texture.zig");
const DrawEncoder = @import("DrawEncoder.zig");
const UniformStore = @import("UniformStore.zig");
const Material = @This();

// ---- Material kinds ---------------------------------------------------------

/// Flat unlit surface - just a color, optionally multiplied with a texture.
pub const Unlit = struct {
    color: math.Vec4 = .{ .x = 1, .y = 1, .z = 1, .w = 1 },
    texture: ?*const Texture = null,

    pub fn bind(self: Unlit, enc: DrawEncoder, u: *UniformStore) void {
        const h_color = u.vec4("u_color");
        const h_use_tex = u.vec4("u_useTexture");
        enc.setVec4(h_color, &self.color);

        if (self.texture) |tex| {
            const h_sampler = u.sampler("s_texColor");
            enc.setTexture(0, h_sampler, tex.handle, std.math.maxInt(u32));
            const use: math.Vec4 = .{ .x = 1, .y = 0, .z = 0, .w = 0 };
            enc.setVec4(h_use_tex, &use);
        } else {
            const no_use: math.Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
            enc.setVec4(h_use_tex, &no_use);
        }
    }
};

/// Blinn-Phong lit surface. Supports up to 4 directional lights.
/// Lights are supplied per-frame by RenderWorld before flush.
pub const BlinnPhong = struct {
    albedo: math.Vec4 = .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1 },
    albedo_texture: ?*const Texture = null,
    specular: math.Vec4 = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 32 },

    pub fn bind(self: BlinnPhong, enc: DrawEncoder, u: *UniformStore) void {
        const h_albedo = u.vec4("u_albedo");
        const h_specular = u.vec4("u_specular");
        const h_use_tex = u.vec4("u_useTexture");
        enc.setVec4(h_albedo, &self.albedo);
        enc.setVec4(h_specular, &self.specular);

        if (self.albedo_texture) |tex| {
            const h_sampler = u.sampler("s_texColor");
            enc.setTexture(0, h_sampler, tex.handle, std.math.maxInt(u32));
            const use: math.Vec4 = .{ .x = 1, .y = 0, .z = 0, .w = 0 };
            enc.setVec4(h_use_tex, &use);
        } else {
            const no_use: math.Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
            enc.setVec4(h_use_tex, &no_use);
        }
    }
};

pub const PbrTextures = struct {
    albedo: ?*const Texture = null,
    normal: ?*const Texture = null,
    metallic_roughness: ?*const Texture = null,
    occlusion: ?*const Texture = null,
    emissive: ?*const Texture = null,
};

/// PBR (Physically Based Rendering) lit surface using Cook-Torrance BRDF.
/// Supports metallic/roughness workflow, normal maps, occlusion, and emissive.
pub const Pbr = struct {
    albedo: math.Vec4 = .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 },
    metallic: f32 = 0.0,
    roughness: f32 = 0.5,
    occlusion_strength: f32 = 1.0,
    emissive: math.Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 1.0 },
    textures: PbrTextures = .{},

    pub fn bind(self: Pbr, enc: DrawEncoder, u: *UniformStore) void {
        const h_albedo = u.vec4("u_albedo");
        const h_metallic_roughness = u.vec4("u_metallicRoughness");
        const h_emissive = u.vec4("u_emissive");
        const h_occlusion_strength = u.vec4("u_occlusionStrength");
        const h_use_textures = u.vec4("u_useTextures");

        enc.setVec4(h_albedo, &self.albedo);
        const mr: math.Vec4 = .{ .x = self.metallic, .y = self.roughness, .z = 0, .w = 0 };
        enc.setVec4(h_metallic_roughness, &mr);
        enc.setVec4(h_emissive, &self.emissive);
        const os: math.Vec4 = .{ .x = self.occlusion_strength, .y = 0, .z = 0, .w = 0 };
        enc.setVec4(h_occlusion_strength, &os);

        var use_textures: math.Vec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
        if (self.textures.albedo) |tex| {
            const h_sampler = u.sampler("s_albedo");
            enc.setTexture(0, h_sampler, tex.handle, std.math.maxInt(u32));
            use_textures.x = 1;
        }
        if (self.textures.normal) |tex| {
            const h_sampler = u.sampler("s_normal");
            enc.setTexture(1, h_sampler, tex.handle, std.math.maxInt(u32));
            use_textures.y = 1;
        }
        if (self.textures.metallic_roughness) |tex| {
            const h_sampler = u.sampler("s_metallicRoughness");
            enc.setTexture(2, h_sampler, tex.handle, std.math.maxInt(u32));
            use_textures.z = 1;
        }
        if (self.textures.occlusion) |tex| {
            const h_sampler = u.sampler("s_occlusion");
            enc.setTexture(3, h_sampler, tex.handle, std.math.maxInt(u32));
            use_textures.w = 1;
        }
        enc.setVec4(h_use_textures, &use_textures);
    }
};

/// Fully custom material: user-supplied shader + bind callback.
pub const Custom = struct {
    /// The shader program. Must be kept alive for the lifetime of this material.
    /// The bind_fn is called before each draw — set any uniforms / textures here.
    bind_fn: *const fn (enc: DrawEncoder, u: *UniformStore) void,
};

// ---- Tagged union -----------------------------------------------------------

pub const Kind = union(enum) {
    unlit: Unlit,
    blinn_phong: BlinnPhong,
    pbr: Pbr,
    custom: Custom,
};

kind: Kind,

// ---- Constructors -----------------------------------------------------------

pub fn unlit(color: math.Vec4) Material {
    return .{ .kind = .{ .unlit = .{ .color = color } } };
}

pub fn unlitTextured(color: math.Vec4, tex: *const Texture) Material {
    return .{ .kind = .{ .unlit = .{ .color = color, .texture = tex } } };
}

pub fn blinnPhong(albedo: math.Vec4) Material {
    return .{ .kind = .{ .blinn_phong = .{ .albedo = albedo } } };
}

pub fn blinnPhongTextured(albedo: math.Vec4, albedo_texture: *const Texture) Material {
    return .{ .kind = .{ .blinn_phong = .{ .albedo = albedo, .albedo_texture = albedo_texture } } };
}

pub fn pbr(albedo: math.Vec4, metallic: f32, roughness: f32) Material {
    return .{ .kind = .{ .pbr = .{ .albedo = albedo, .metallic = metallic, .roughness = roughness } } };
}

pub fn pbrTextured(albedo: *const Texture, metallic_roughness: ?*const Texture, normal: ?*const Texture, occlusion: ?*const Texture) Material {
    return .{
        .kind = .{
            .pbr = .{
                .textures = .{
                    .albedo = albedo,
                    .metallic_roughness = metallic_roughness,
                    .normal = normal,
                    .occlusion = occlusion,
                },
            },
        },
    };
}

pub fn custom(bind_fn: *const fn (DrawEncoder, *UniformStore) void) Material {
    return .{ .kind = .{ .custom = .{ .bind_fn = bind_fn } } };
}

// ---- Bind -------------------------------------------------------------------

/// Upload all material uniforms to bgfx for the next draw call.
pub fn bind(self: Material, enc: DrawEncoder, u: *UniformStore) void {
    switch (self.kind) {
        .unlit => |m| m.bind(enc, u),
        .blinn_phong => |m| m.bind(enc, u),
        .pbr => |m| m.bind(enc, u),
        .custom => |m| m.bind_fn(enc, u),
    }
}
