const c = @import("c.zig").c;
const std = @import("std");
const Monitor = @This();
const enums = @import("enums.zig");
handle: *c.RGFW_monitor,

pub fn getX(self: *const Monitor) u32 {
    return @intCast(self.handle.x);
}

pub fn getY(self: *const Monitor) u32 {
    return @intCast(self.handle.y);
}

pub fn getName(self: *const Monitor) []const u8 {
    const ptr: [*:0]const u8 = @ptrCast(&self.handle.name);
    return std.mem.span(ptr);
}

pub fn getScaleX(self: *const Monitor) f32 {
    return self.handle.scaleX;
}

pub fn getScaleY(self: *const Monitor) f32 {
    return self.handle.scaleY;
}

pub fn getPixelRatio(self: *const Monitor) f32 {
    return self.handle.pixelRatio;
}

pub fn getPhysicalWidth(self: *const Monitor) f32 {
    return (self.handle.physWidth);
}

pub fn getPhysicalHeight(self: *const Monitor) f32 {
    return (self.handle.physHeight);
}

pub fn getMode(self: *const Monitor) Mode {
    return .{
        .width = self.handle.mode.w,
        .height = self.handle.mode.h,
        .refresh_rate = self.handle.mode.refreshRate,
        .red = self.handle.mode.red,
        .blue = self.handle.mode.blue,
        .green = self.handle.mode.green,
        .src = self.handle.mode.src,
    };
}

pub const Mode = struct {
    width: i32,
    height: i32,
    refresh_rate: f32,
    red: u8,
    blue: u8,
    green: u8,
    src: ?*anyopaque,
};

pub fn getPrimary() Monitor {
    const prim = c.RGFW_getPrimaryMonitor();
    return Monitor{ .handle = prim };
}

pub fn getAll() []Monitor {
    const monitors = c.RGFW_getMonitors();
    return monitors[0..c.RGFW_MAX_MONITORS];
}
