const std = @import("std");
const orin = @import("orin");

/// A simple asset type. Must implement `load`.
const MyAsset = struct {
    content: []const u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, data: []const u8) !MyAsset {
        // Simulate heavy parsing
        std.Thread.sleep(100 * std.time.ns_per_ms);
        return MyAsset{
            .content = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MyAsset) void {
        self.allocator.free(self.content);
    }
};

/// Global state for the demo
var asset_handle: orin.Handle(MyAsset) = undefined;

fn loadSystem(world: *orin.World) void {
    const server = world.getMutResource(orin.AssetServer).?;
    asset_handle = server.load(MyAsset, world, "tmp/test_asset.txt");
    std.debug.print("[demo] Requesting asset load... (Handle: {d})\n", .{asset_handle.id});
}

fn checkSystem(world: *orin.World) void {
    const assets = world.getMutResource(orin.Assets(MyAsset)) orelse return;
    if (assets.get(asset_handle)) |asset| {
        std.debug.print("[demo] Asset ready! Content: '{s}'\n", .{asset.content});
        world.getMutResource(orin.App).?.stop();
    } else {
        std.debug.print("[demo] Asset still loading...\n", .{});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Create a dummy asset file
    try std.fs.cwd().makePath("tmp");
    try std.fs.cwd().writeFile(.{ .sub_path = "tmp/test_asset.txt", .data = "Orin Engine Parallel Assets!" });

    // 2. Setup App
    var app = try orin.App.init(allocator, .{ .name = "asset_demo" });
    defer app.deinit();

    // 3. Register systems
    // One-shot load system (run manually or in a custom phase)
    loadSystem(&app.world);

    // Repeated check system
    app.addSystem(checkSystem).commit();

    // 4. Run loop
    std.debug.print("[demo] Starting app loop...\n", .{});
    app.run();
    std.debug.print("[demo] App stopped.\n", .{});
}
