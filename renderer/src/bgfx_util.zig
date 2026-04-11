const std = @import("std");
const zbgfx = @import("bgfx");
const bgfx = zbgfx.bgfx;

pub var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};

pub inline fn isValid(handle: anytype) bool {
    return handle.idx < std.math.maxInt(u16);
}
