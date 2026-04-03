const bgfx = @import("bgfx").bgfx;
const ShaderProgram = @This();
const isValid = @import("bgfx_util.zig").isValid;

program_handle: bgfx.ProgramHandle,
vertex_shader: bgfx.ShaderHandle,
fragment_shader: bgfx.ShaderHandle,

pub fn initFromMem(
    vertex_mem: [*c]const bgfx.Memory,
    fragment_mem: [*c]const bgfx.Memory,
) !ShaderProgram {
    const vert = bgfx.createShader(vertex_mem);
    const frag = bgfx.createShader(fragment_mem);

    if (!isValid(vert)) {
        return error.InvalidVertexShader;
    }
    if (!isValid(frag)) {
        return error.InvalidFragmentShader;
    }

    const program = bgfx.createProgram(vert, frag, false);
    if (!isValid(program)) {
        return error.InvalidProgram;
    }

    return ShaderProgram{
        .program_handle = program,
        .vertex_shader = vert,
        .fragment_shader = frag,
    };
}

pub fn init(vertex_src: []const u8, fragment_src: []const u8) !ShaderProgram {
    const vert = bgfx.createShader(bgfx.copy(@ptrCast(vertex_src.ptr), @intCast(vertex_src.len)));
    if (!isValid(vert)) {
        return error.InvalidVertexShader;
    }
    const frag = bgfx.createShader(bgfx.copy(@ptrCast(fragment_src.ptr), @intCast(fragment_src.len)));
    if (!isValid(frag)) {
        bgfx.destroyShader(vert);
        return error.InvalidFragmentShader;
    }

    const program = bgfx.createProgram(vert, frag, false);
    if (!isValid(program)) {
        bgfx.destroyShader(vert);
        bgfx.destroyShader(frag);
        return error.InvalidProgram;
    }

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
