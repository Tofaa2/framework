const bgfx = @import("bgfx").bgfx;
const DrawState = @This();

    state_flags: u64 = bgfx.StateFlags_Default,
    blend_rgba: u32 = 0,

    pub const default_3d = DrawState{
        .state_flags = bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA |
            bgfx.StateFlags_WriteZ |
            bgfx.StateFlags_DepthTestLess |
            bgfx.StateFlags_CullCcw |
            bgfx.StateFlags_Msaa,
    };

    pub const default_2d = DrawState{
        .state_flags = bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA |
            stateBlendFunc(bgfx.StateFlags_BlendSrcAlpha, bgfx.StateFlags_BlendInvSrcAlpha),
    };
    pub const no_blend = DrawState{
        .state_flags = bgfx.StateFlags_WriteRgb |
            bgfx.StateFlags_WriteA,
    };

    pub fn stateBlendFunc(src: u64, dst: u64) u64 {
        const src_idx = src >> bgfx.StateFlags_BlendShift;
        const dst_idx = dst >> bgfx.StateFlags_BlendShift;
        // set both RGB and Alpha blend factors
        return (src_idx | (dst_idx << 4) | (src_idx << 8) | (dst_idx << 12)) << bgfx.StateFlags_BlendShift;
    }

