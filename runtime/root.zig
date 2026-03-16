const std = @import("std");

pub const prelude = @import("prelude.zig");

pub const App = @import("App.zig");
pub const PluginManager = prelude.plugin.PluginManager(App);
pub const Time = @import("Time.zig");
