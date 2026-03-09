const std = @import("std");
const builtin = @import("builtin");

pub const windows = @import("backend/windows.zig");

pub const input = @import("input.zig");

pub const Window = switch (builtin.os.tag) {
    .windows => GenericWindow(windows.Backend),
    else => @compileError("Your platform is not supported"),
};

/// Generic window type that works with any backend
pub fn GenericWindow(comptime Backend: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        backend: *Backend,

        pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !Self {
            const backend = Backend.init(allocator, title, width, height);
            errdefer backend.deinit();

            return Self{
                .allocator = allocator,
                .backend = backend,
            };
        }

        pub fn deinit(self: *Self) void {
            self.backend.deinit();
        }

        pub fn update(self: *Self) void {
            self.backend.update();
        }

        pub fn getInput(self: *Self) *input.InputState {
            return self.backend.getInput();
        }

        pub fn shouldClose(self: *Self) bool {
            return self.backend.shouldClose();
        }

        pub fn getNativeHandle(self: *Self) *anyopaque {
            return self.backend.getNativeHandle();
        }

        pub fn getWin32ModuleHandle(self: *Self) ?*anyopaque {
            return self.backend.getWin32ModuleHandle();
        }

        pub fn setMouseLockState(self: *Self, locked: bool) void {
            self.backend.setMouseLockState(locked);
        }

    };
}
