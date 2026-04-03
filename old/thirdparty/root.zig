pub const rgfw = @cImport({
    @cInclude("RGFW.h");
});

pub const miniaudio = @cImport({
    @cInclude("miniaudio.h");
});

pub const stb = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_truetype.h");
    @cInclude("stb_image_write.h");
});

pub const microui = @cImport({
    @cInclude("microui.h");
});
