const std = @import("std");
const builtin = @import("builtin");

pub const windows = @import("backend/windows.zig");

pub const keyboard = @import("keyboard.zig");
pub const Key = keyboard.Key;
pub const KeyModifier = keyboard.KeyModifier;

pub fn Window() type {
    const os = builtin.os.tag;
    if (os == .windows) {
        return GenericWindow(windows.Backend);
    } else {
        @panic("Your platform is not supported by the framework window library");
    }
}

pub fn GenericWindow(
    comptime Backend: type,
) type {
    return struct {
        backend: *Backend,
        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !Self {
            return Self{
                .backend = Backend.init(allocator, title, width, height),
            };
        }

        pub fn deinit(self: *Self) void {
            self.backend.deinit();
        }

        pub fn update(self: *Self) void {
            self.backend.update();
        }

        pub fn shouldClose(self: *Self) bool {
            return self.backend.shouldClose();
        }
        
        pub fn getNativeHandle(self: *Self) *anyopaque {
            return self.backend.getNativeHandle();
        }
    };
}
