pub const dyn = @import("dyn.zig");
pub const type_id = @import("type_id.zig");
pub const stb_image = @import("stb_image.zig");
pub const cli = @import("cli.zig");
pub const trait = @import("trait.zig");

const std = @import("std");
pub fn ApiExport(comptime T: type) type {
    return struct {
        pub const Inner = T;
        
        comptime {
            for (std.meta.declarations(T)) |decl| {
                // Re-export each declaration by name
                @export(@field(T, decl.name), .{ .name = decl.name });
            }
        }
    };
}
