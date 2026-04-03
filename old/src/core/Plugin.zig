/// Interface for extending the application with custom systems or functionality.
/// Plugins are initialized only once when added to the App structure.
const root = @import("../root.zig");
const App = root.App;

/// Basic plugin interface
/// This serves as a simple way to extend the app without a lot of boilerplate.
pub const Plugin = struct {
    /// Callback function that initializes the plugin with a given App instance.
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
