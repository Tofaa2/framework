pub const utils = @import("utils/root.zig");
pub const primitive = @import("primitive/root.zig");
pub const renderer = @import("renderer/root.zig");
pub const core = @import("core/root.zig");
pub const platform = @import("platform/root.zig");
pub const ecs = @import("ecs");

pub const App = @import("App.zig");

comptime {
    @import("std").testing.refAllDeclsRecursive(@This());
}
