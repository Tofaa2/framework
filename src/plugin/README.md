# framework-plugin

An opinionated plugin system originally developed for app-sdk


```zig
const plugin = @import("framework-plugin");

pub const Context = struct {
    value: i32,
};

pub const CountUpPlugin = struct {
    
};

pub const PrintPlugin = struct {
    pub fn init(self: *PrintPlugin, ctx: *Context) void {
        std.debug.print("Value: {d}\n", .{ctx.value});
    }

}

pub fn main() void {
    var allocator = ...;
    
    var pm = plugin.PluginManager(Context).init(allocator);
    defer pm.deinit();
    
    try pm.add(PrintPlugin {});
    try pm.add(CountUpPlugin{});
}
```
