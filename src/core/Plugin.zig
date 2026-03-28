const root = @import("../root.zig");
const App = root.App;

/// Basic  plugin interface
/// This is not really something i like in the current scope of the design but
/// it serves as a simple way to extend the app without a lot of boilerplate.
pub const Plugin = struct {
    buildFn: *const fn (*App) void,

    pub fn init(buildFn: *const fn (*App) void) Plugin {
        return .{
            .buildFn = buildFn,
        };
    }

    pub fn build(self: Plugin, app: *App) void {
        self.buildFn(app);
    }
};
