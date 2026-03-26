const root = @import("../root.zig");
const App = root.App;

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
