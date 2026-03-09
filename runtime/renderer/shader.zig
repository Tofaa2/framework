const std = @import("std");
const bgfx = @import("bgfx.zig");

pub const ShaderProgram = struct {
    program_handle: bgfx.ProgramHandle,
    vertex_shader: bgfx.ShaderHandle,
    fragment_shader: bgfx.ShaderHandle,

    pub fn init(vertex_src: []const u8, fragment_src: []const u8) ShaderProgram {
        // const vert = bgfx.createShader(bgfx.copy(@ptrCast(&vertex_src), @intCast(vertex_src.len * @sizeOf(u8))));
        // const frag = bgfx.createShader(bgfx.copy(@ptrCast(&fragment_src), @intCast(fragment_src.len * @sizeOf(u8))));

        const vert = bgfx.createShader(bgfx.copy(@ptrCast(vertex_src.ptr), @intCast(vertex_src.len)));
        const frag = bgfx.createShader(bgfx.copy(@ptrCast(fragment_src.ptr), @intCast(fragment_src.len)));

        const program = bgfx.createProgram(vert, frag, false);

        return ShaderProgram{
            .program_handle = program,
            .vertex_shader = vert,
            .fragment_shader = frag,
        };
    }

    pub fn deinit(self: *ShaderProgram) void {
        bgfx.destroyShader(self.vertex_shader);
        bgfx.destroyShader(self.fragment_shader);
        bgfx.destroyProgram(self.program_handle);
    }
};
