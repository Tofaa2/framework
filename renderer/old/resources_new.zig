/// GPU resource management (meshes, textures, shaders, framebuffers)
const std = @import("std");
const bgfx = @import("bgfx").bgfx;
const core = @import("core.zig");

pub const PostVertex = extern struct {
    position: [3]f32,
    uv: [2]f32,
};

pub const MeshHandle = enum(u32) { invalid = std.math.maxInt(u32), _ };
pub const TextureHandle = enum(u32) { invalid = std.math.maxInt(u32), _ };
pub const ShaderHandle = enum(u32) { invalid = std.math.maxInt(u32), _ };
pub const ProgramHandle = enum(u32) { invalid = std.math.maxInt(u32), _ };
pub const FramebufferHandle = enum(u32) { invalid = std.math.maxInt(u32), _ };

pub fn isValid(h: anytype) bool {
    return h != @as(@TypeOf(h), .invalid);
}

fn isBgfXHandleValid(h: anytype) bool {
    const fields = std.meta.fields(@TypeOf(h));
    if (fields.len == 1 and fields[0].type == u16) {
        return @as(u16, @field(h, fields[0].name)) != 0xFFFF;
    }
    return true;
}

pub const Mesh = struct {
    vbh: bgfx.VertexBufferHandle,
    ibh: bgfx.IndexBufferHandle,
    vertex_count: u32,
    index_count: u32,
};

pub const Texture = struct {
    handle: bgfx.TextureHandle,
    width: u16,
    height: u16,
};

pub const Shader = struct {
    handle: bgfx.ShaderHandle,
};

pub const Program = struct {
    handle: bgfx.ProgramHandle,
    vs: ShaderHandle,
    fs: ShaderHandle,
};

pub const Framebuffer = struct {
    handle: bgfx.FrameBufferHandle,
    textures: []TextureHandle,
    width: u16,
    height: u16,
};

pub const ResourcePool = struct {
    allocator: std.mem.Allocator,
    meshes: std.ArrayListUnmanaged(Mesh),
    textures: std.ArrayListUnmanaged(Texture),
    shaders: std.ArrayListUnmanaged(Shader),
    programs: std.ArrayListUnmanaged(Program),
    framebuffers: std.ArrayListUnmanaged(Framebuffer),

    pub fn init(allocator: std.mem.Allocator) ResourcePool {
        return .{
            .allocator = allocator,
            .meshes = .{},
            .textures = .{},
            .shaders = .{},
            .programs = .{},
            .framebuffers = .{},
        };
    }

    pub fn deinit(self: *ResourcePool) void {
        for (self.meshes.items) |mesh| {
            bgfx.destroyVertexBuffer(mesh.vbh);
            bgfx.destroyIndexBuffer(mesh.ibh);
        }
        for (self.textures.items) |tex| {
            bgfx.destroyTexture(tex.handle);
        }
        for (self.shaders.items) |shader| {
            bgfx.destroyShader(shader.handle);
        }
        for (self.programs.items) |prog| {
            bgfx.destroyProgram(prog.handle);
        }
        for (self.framebuffers.items) |fb| {
            bgfx.destroyFrameBuffer(fb.handle);
            self.allocator.free(fb.textures);
        }
        self.meshes.deinit(self.allocator);
        self.textures.deinit(self.allocator);
        self.shaders.deinit(self.allocator);
        self.programs.deinit(self.allocator);
        self.framebuffers.deinit(self.allocator);
    }

    pub fn createMesh(self: *ResourcePool, layout: *const bgfx.VertexLayout, vertices: []const core.Vertex, indices: []const u16) !MeshHandle {
        const vmem = bgfx.copy(std.mem.sliceAsBytes(vertices).ptr, @intCast(std.mem.sliceAsBytes(vertices).len));
        const imem = bgfx.copy(std.mem.sliceAsBytes(indices).ptr, @intCast(std.mem.sliceAsBytes(indices).len));

        const vbh = bgfx.createVertexBuffer(vmem, layout, bgfx.BufferFlags_None);
        const ibh = bgfx.createIndexBuffer(imem, bgfx.BufferFlags_None);

        if (!isBgfXHandleValid(vbh) or !isBgfXHandleValid(ibh)) {
            return error.MeshCreationFailed;
        }

        const h: MeshHandle = @enumFromInt(self.meshes.items.len);
        try self.meshes.append(self.allocator, .{
            .vbh = vbh,
            .ibh = ibh,
            .vertex_count = @intCast(vertices.len),
            .index_count = @intCast(indices.len),
        });
        return h;
    }

    pub fn getMesh(self: *const ResourcePool, h: MeshHandle) ?*const Mesh {
        if (!isValid(h)) return null;
        return &self.meshes.items[@intFromEnum(h)];
    }

    pub fn createPostQuad(self: *ResourcePool) !MeshHandle {
        const vertices = [_]PostVertex{
            .{ .position = .{ -1, -1, 0 }, .uv = .{ 0, 0 } },
            .{ .position = .{ 1, -1, 0 }, .uv = .{ 1, 0 } },
            .{ .position = .{ 1, 1, 0 }, .uv = .{ 1, 1 } },
            .{ .position = .{ -1, 1, 0 }, .uv = .{ 0, 1 } },
        };
        const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

        var layout = std.mem.zeroes(bgfx.VertexLayout);
        _ = layout.begin(bgfx.getRendererType());
        _ = layout.add(.Position, 3, .Float, false, false);
        _ = layout.add(.TexCoord0, 2, .Float, false, false);
        layout.end();

        const vmem = bgfx.copy(std.mem.sliceAsBytes(&vertices).ptr, @intCast(std.mem.sliceAsBytes(&vertices).len));
        const imem = bgfx.copy(std.mem.sliceAsBytes(&indices).ptr, @intCast(std.mem.sliceAsBytes(&indices).len));

        const vbh = bgfx.createVertexBuffer(vmem, &layout, bgfx.BufferFlags_None);
        const ibh = bgfx.createIndexBuffer(imem, bgfx.BufferFlags_None);

        if (!isBgfXHandleValid(vbh) or !isBgfXHandleValid(ibh)) {
            return error.MeshCreationFailed;
        }

        const h: MeshHandle = @enumFromInt(self.meshes.items.len);
        try self.meshes.append(self.allocator, .{
            .vbh = vbh,
            .ibh = ibh,
            .vertex_count = 4,
            .index_count = 6,
        });
        return h;
    }

    pub fn createTexture2D(self: *ResourcePool, width: u16, height: u16, rgba_data: []const u8) !TextureHandle {
        const mem = bgfx.copy(rgba_data.ptr, @intCast(rgba_data.len));
        const handle = bgfx.createTexture2D(width, height, false, 1, .RGBA8, bgfx.TextureFlags_None, mem, 0);
        if (!isBgfXHandleValid(handle)) return error.TextureCreationFailed;
        const h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = handle,
            .width = width,
            .height = height,
        });
        return h;
    }

    pub fn createTexture2DFloat(self: *ResourcePool, width: u16, height: u16, rgba_data: [*]const f32) !TextureHandle {
        const mem = bgfx.copy(rgba_data, @intCast(width * height * 4 * @sizeOf(f32)));
        const handle = bgfx.createTexture2D(width, height, false, 1, .RGBA32F, bgfx.TextureFlags_None, mem, 0);
        if (!isBgfXHandleValid(handle)) return error.TextureCreationFailed;
        const h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = handle,
            .width = width,
            .height = height,
        });
        return h;
    }

    pub fn createCubemap(self: *ResourcePool, size: u16, px: [*]const f32, nx: [*]const f32, py: [*]const f32, ny: [*]const f32, pz: [*]const f32, nz: [*]const f32) !TextureHandle {
        const face_size = @as(u32, size) * @as(u32, size) * 4 * @sizeOf(f32);
        var face_mems: [6][*c]const bgfx.Memory = undefined;
        face_mems[0] = bgfx.copy(px, face_size);
        face_mems[1] = bgfx.copy(nx, face_size);
        face_mems[2] = bgfx.copy(py, face_size);
        face_mems[3] = bgfx.copy(ny, face_size);
        face_mems[4] = bgfx.copy(pz, face_size);
        face_mems[5] = bgfx.copy(nz, face_size);
        const handle = bgfx.createTextureCube(size, false, 1, .RGBA32F, bgfx.TextureFlags_None, @as([*c]const bgfx.Memory, @ptrCast(&face_mems)), 0);
        if (!isBgfXHandleValid(handle)) return error.TextureCreationFailed;
        const h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = handle,
            .width = size,
            .height = size,
        });
        return h;
    }

    pub fn createPrefilteredCubemap(self: *ResourcePool, size: u16, px: [*]const f32, nx: [*]const f32, py: [*]const f32, ny: [*]const f32, pz: [*]const f32, nz: [*]const f32) !TextureHandle {
        return self.createCubemap(size, px, nx, py, ny, pz, nz);
    }

    pub fn createCubemapFromFaces(self: *ResourcePool, allocator: std.mem.Allocator, faces: [6][]f32, size: u16) !TextureHandle {
        _ = allocator;
        const face_size = @as(u32, size) * @as(u32, size) * 4 * @sizeOf(f32);
        var face_mems: [6][*c]const bgfx.Memory = undefined;
        for (0..6) |i| face_mems[i] = bgfx.copy(&faces[i][0], face_size);
        const handle = bgfx.createTextureCube(size, false, 1, .RGBA32F, bgfx.TextureFlags_None, @as([*c]const bgfx.Memory, @ptrCast(&face_mems)), 0);
        if (!isBgfXHandleValid(handle)) return error.TextureCreationFailed;
        const h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = handle,
            .width = size,
            .height = size,
        });
        return h;
    }

    pub fn createPrefilteredCubemapFromFaces(self: *ResourcePool, allocator: std.mem.Allocator, faces: *const [6][]f32, size: u16, mips: u8) !TextureHandle {
        _ = allocator;
        _ = mips;
        const face_size = @as(u32, size) * @as(u32, size) * 4 * @sizeOf(f32);
        var face_mems: [6][*c]const bgfx.Memory = undefined;
        for (0..6) |i| face_mems[i] = bgfx.copy(&faces[i][0], face_size);
        const handle = bgfx.createTextureCube(size, false, 1, .RGBA32F, bgfx.TextureFlags_Srgb, @as([*c]const bgfx.Memory, @ptrCast(&face_mems)), 0);
        if (!isBgfXHandleValid(handle)) return error.TextureCreationFailed;
        const h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = handle,
            .width = size,
            .height = size,
        });
        return h;
    }

    pub fn getTexture(self: *const ResourcePool, h: TextureHandle) ?*const Texture {
        if (!isValid(h)) return null;
        return &self.textures.items[@intFromEnum(h)];
    }

    pub fn createShader(self: *ResourcePool, data: []const u8) !ShaderHandle {
        const mem = bgfx.copy(data.ptr, @intCast(data.len));
        const handle = bgfx.createShader(mem);
        if (!isBgfXHandleValid(handle)) return error.ShaderCreationFailed;
        const h: ShaderHandle = @enumFromInt(self.shaders.items.len);
        try self.shaders.append(self.allocator, .{ .handle = handle });
        return h;
    }

    pub fn getShader(self: *const ResourcePool, h: ShaderHandle) ?*const Shader {
        if (!isValid(h)) return null;
        return &self.shaders.items[@intFromEnum(h)];
    }

    pub fn createProgram(self: *ResourcePool, vs: ShaderHandle, fs: ShaderHandle) !ProgramHandle {
        const vs_data = self.getShader(vs) orelse return error.InvalidShader;
        const fs_data = self.getShader(fs) orelse return error.InvalidShader;
        const handle = bgfx.createProgram(vs_data.handle, fs_data.handle, false);
        if (!isBgfXHandleValid(handle)) return error.ProgramCreationFailed;
        const h: ProgramHandle = @enumFromInt(self.programs.items.len);
        try self.programs.append(self.allocator, .{
            .handle = handle,
            .vs = vs,
            .fs = fs,
        });
        return h;
    }

    pub fn getProgram(self: *const ResourcePool, h: ProgramHandle) ?*const Program {
        if (!isValid(h)) return null;
        return &self.programs.items[@intFromEnum(h)];
    }

    pub fn createProgramFromMemory(self: *ResourcePool, vs: [*c]const bgfx.Memory, fs: [*c]const bgfx.Memory) !ProgramHandle {
        const vs_shader = bgfx.createShader(vs);
        const fs_shader = bgfx.createShader(fs);
        if (!isBgfXHandleValid(vs_shader) or !isBgfXHandleValid(fs_shader)) {
            return error.ShaderCreationFailed;
        }
        const handle = bgfx.createProgram(vs_shader, fs_shader, false);
        if (!isBgfXHandleValid(handle)) return error.ProgramCreationFailed;
        const h: ProgramHandle = @enumFromInt(self.programs.items.len);
        try self.programs.append(self.allocator, .{
            .handle = handle,
            .vs = .invalid,
            .fs = .invalid,
        });
        return h;
    }

    pub fn createWhiteTexture(self: *ResourcePool) !TextureHandle {
        const white: [4]u8 = .{ 255, 255, 255, 255 };
        return self.createTexture2D(1, 1, &white);
    }

    pub fn createCheckerboardTexture(self: *ResourcePool, size: u16) !TextureHandle {
        var data = try self.allocator.alloc(u8, @as(usize, size) * size * 4);
        defer self.allocator.free(data);

        for (0..size) |y| {
            for (0..size) |x| {
                const idx = (y * size + x) * 4;
                const gray: u8 = if (((x / 8) + (y / 8)) % 2 == 0) 200 else 80;
                data[idx + 0] = gray;
                data[idx + 1] = gray;
                data[idx + 2] = gray;
                data[idx + 3] = 255;
            }
        }
        return self.createTexture2D(size, size, data);
    }

    pub fn createFramebufferSimple(self: *ResourcePool, width: u16, height: u16, has_depth: bool) !FramebufferHandle {
        _ = has_depth;
        const fb_handle = bgfx.createFrameBufferScaled(.Equal, .RGBA8, 0);
        if (!isBgfXHandleValid(fb_handle)) return error.FramebufferCreationFailed;

        const fb_tex = bgfx.getTexture(fb_handle, 0);
        const tex_h: TextureHandle = @enumFromInt(self.textures.items.len);
        try self.textures.append(self.allocator, .{
            .handle = fb_tex,
            .width = width,
            .height = height,
        });

        const fb_h: FramebufferHandle = @enumFromInt(self.framebuffers.items.len);
        const tex_handles = try self.allocator.alloc(TextureHandle, 1);
        tex_handles[0] = tex_h;

        try self.framebuffers.append(self.allocator, .{
            .handle = fb_handle,
            .textures = tex_handles,
            .width = width,
            .height = height,
        });

        return fb_h;
    }

    pub fn getFramebufferTexture(self: *const ResourcePool, fb: FramebufferHandle, attachment: u8) TextureHandle {
        if (!isValid(fb)) return .invalid;
        const fb_data = self.framebuffers.items[@intFromEnum(fb)];
        if (attachment >= fb_data.textures.len) return .invalid;
        return fb_data.textures[attachment];
    }

    pub fn getFramebuffer(self: *const ResourcePool, h: FramebufferHandle) ?*const Framebuffer {
        if (!isValid(h)) return null;
        return &self.framebuffers.items[@intFromEnum(h)];
    }

    pub fn loadHDR(self: *ResourcePool, allocator: std.mem.Allocator, path: []const u8) !struct { data: []f32, width: u32, height: u32 } {
        _ = self;
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var header: [11]u8 = undefined;
        _ = try file.read(&header);

        if (!std.mem.startsWith(u8, &header, "#?RADIANCE")) {
            return error.InvalidHDRFormat;
        }

        var width: u32 = 0;
        var height: u32 = 0;
        var file_pos: u64 = 11;

        while (true) {
            var line_len: usize = 0;
            var line_buf: [256]u8 = undefined;
            while (line_len < 255) {
                var b_buf: [1]u8 = undefined;
                const n = try file.pread(&b_buf, file_pos + line_len);
                if (n == 0 or b_buf[0] == '\n') break;
                line_buf[line_len] = b_buf[0];
                line_len += 1;
            }

            if (line_len == 0) break;

            file_pos += line_len + 1;

            const line = line_buf[0..line_len];
            if (line.len > 3 and line[0] == '-') {
                if (line[1] == 'Y' and line[2] == ' ') {
                    var parts = std.mem.splitScalar(u8, line[3..], ' ');
                    const height_str = parts.first();
                    height = try std.fmt.parseInt(u32, height_str, 10);
                }
                if (line[1] == '+' and line[2] == 'X' and line[3] == ' ') {
                    var parts = std.mem.splitScalar(u8, line[4..], ' ');
                    const width_str = parts.first();
                    width = try std.fmt.parseInt(u32, width_str, 10);
                }
                if (width != 0 and height != 0) break;
            }
        }

        if (width == 0 or height == 0) {
            return error.InvalidHDRResolution;
        }

        var rgb_data = try allocator.alloc(u8, width * height * 4);
        defer allocator.free(rgb_data);

        var y: u32 = 0;
        while (y < height) : (y += 1) {
            var scanline_len_buf: [4]u8 = undefined;
            _ = try file.pread(&scanline_len_buf, file_pos);
            file_pos += 4;
            const scanline_len = scanline_len_buf;
            const len = @as(u32, scanline_len[0]) | (@as(u32, scanline_len[1]) << 8) | (@as(u32, scanline_len[2]) << 16);

            if (len >= 32768) {
                var x: u32 = 0;
                while (x < width) : (x += 1) {
                    var buf: [1]u8 = undefined;
                    _ = try file.pread(&buf, file_pos);
                    file_pos += 1;
                    @memset(rgb_data[(y * width + x) * 4 .. (y * width + x) * 4 + 4], buf[0]);
                }
                continue;
            }

            var x: u32 = 0;
            var byte_idx: u32 = 0;

            while (x < width) {
                var first_byte_buf: [1]u8 = undefined;
                _ = try file.pread(&first_byte_buf, file_pos);
                file_pos += 1;
                byte_idx += 1;
                const first_byte = first_byte_buf[0];

                if (first_byte > 128) {
                    const count = first_byte - 128;
                    var value_buf: [1]u8 = undefined;
                    _ = try file.pread(&value_buf, file_pos);
                    file_pos += 1;
                    byte_idx += 1;
                    const val = value_buf[0];

                    var i: u8 = 0;
                    while (i < count) : (i += 1) {
                        rgb_data[(y * width + x) * 4 + 0] = val;
                        rgb_data[(y * width + x) * 4 + 1] = val;
                        rgb_data[(y * width + x) * 4 + 2] = val;
                        rgb_data[(y * width + x) * 4 + 3] = 255;
                        x += 1;
                    }
                } else {
                    const count = first_byte;

                    var i: u8 = 0;
                    while (i < count) : (i += 1) {
                        var rgb_buf: [3]u8 = undefined;
                        _ = try file.pread(&rgb_buf, file_pos);
                        file_pos += 3;
                        rgb_data[(y * width + x) * 4 + 0] = rgb_buf[0];
                        rgb_data[(y * width + x) * 4 + 1] = rgb_buf[1];
                        rgb_data[(y * width + x) * 4 + 2] = rgb_buf[2];
                        rgb_data[(y * width + x) * 4 + 3] = 255;
                        x += 1;
                        byte_idx += 3;
                    }
                }
            }

            while (byte_idx < len) : (byte_idx += 1) {
                var discard_buf: [1]u8 = undefined;
                _ = try file.pread(&discard_buf, file_pos);
                file_pos += 1;
            }
        }

        var float_data = try allocator.alloc(f32, width * height * 3);
        var i: u32 = 0;
        while (i < width * height) : (i += 1) {
            float_data[i * 3 + 0] = @as(f32, @floatFromInt(rgb_data[i * 4 + 0])) / 255.0;
            float_data[i * 3 + 1] = @as(f32, @floatFromInt(rgb_data[i * 4 + 1])) / 255.0;
            float_data[i * 3 + 2] = @as(f32, @floatFromInt(rgb_data[i * 4 + 2])) / 255.0;
        }

        return .{
            .data = float_data,
            .width = width,
            .height = height,
        };
    }

    pub fn createBRDFLUT(self: *ResourcePool) !TextureHandle {
        const size: u16 = 512;
        const data = try self.allocator.alloc(u8, @as(usize, size) * size * 2 * 4);
        defer self.allocator.free(data);

        var ptr: [*]f32 = @ptrCast(@alignCast(data.ptr));

        var i: u16 = 0;
        while (i < size) : (i += 1) {
            var j: u16 = 0;
            while (j < size) : (j += 1) {
                const NdotV = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(size));
                const roughness = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(size));

                const Vz = NdotV;
                _ = @sqrt(1.0 - NdotV * NdotV);

                var A: f32 = 0.0;
                var B: f32 = 0.0;

                var sample_count: f32 = 0.0;
                var si: u32 = 0;
                while (si < 1024) : (si += 1) {
                    const Xi1 = @as(f32, @floatFromInt(si)) / 1024.0;
                    const Xi2 = radicalInverse(si);

                    const phi = 2.0 * std.math.pi * Xi1;
                    const cos_theta = @sqrt((1.0 - Xi2) / (1.0 + roughness * roughness * roughness - 1.0 * Xi2));
                    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

                    const Hx = @cos(phi) * sin_theta;
                    const Hz = cos_theta;

                    const Lz = 2.0 * NdotV * Hz - Vz;

                    const NdotL = @max(Lz, 0.0);
                    const VdotH = @max(NdotV * Hx + Vz * Hz, 0.0);

                    if (NdotL > 0) {
                        const G = NdotV / (NdotV * (1.0 - 0.5 * roughness * roughness) + 0.5 * roughness * roughness);
                        const G2 = G * NdotL / (4.0 * NdotV);
                        const Fc = pow5(1.0 - VdotH);

                        A += (1.0 - Fc) * G2;
                        B += Fc * G2;
                    }
                    sample_count += 1.0;
                }

                const idx = (@as(usize, i) * size + @as(usize, j)) * 2;
                ptr[idx + 0] = A / sample_count;
                ptr[idx + 1] = B / sample_count;
            }
        }

        return self.createTexture2D(size, @as(u16, @intCast(size * 2)), data);
    }
};

fn radicalInverse(i: u32) f32 {
    var bits = i;
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);
    return @as(f32, @floatFromInt(bits)) / 4294967296.0;
}

fn pow5(x: f32) f32 {
    const x2 = x * x;
    return x2 * x2 * x;
}
