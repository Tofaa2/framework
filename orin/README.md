An opinionated, minimal game and application engine written in Zig.
 
## Getting Started
 
```bash
git clone https://github.com/Tofaa2/framework
cd framework
zig build
```
 
A fully playable snake game built with the engine lives in `examples/snake`:
 
```bash
zig build snake
```
 
## Basic Usage
 
```zig
const runtime = @import("framework-runtime");
const std = @import("std");
 
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
 
    var app = runtime.App.init(.{
        .name = "my_app",
        .allocators = .{
            .frame = arena.allocator(),
            .generic = allocator,
            .world = allocator,
            .frame_arena = arena,
        },
    });
    defer app.deinit();
 
    // spawn a red circle at 400, 300
    const circle = app.world.create();
    app.world.add(circle, runtime.Transform{
        .center = .{ 400.0, 300.0, 0.0 },
    });
    app.world.add(circle, runtime.Renderable{
        .circle = .{ .radius = 50 },
    });
    app.world.add(circle, runtime.Color.red);
 
    // add an update system
    try app.scheduler.addStage(.{
        .name = "my-system",
        .phase = .update,
        .run = mySystem,
    });
 
    app.run();
}
 
fn mySystem(app: *runtime.App) void {
    var query = app.world.view(.{ runtime.Transform, runtime.Renderable }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const transform = query.get(runtime.Transform, entity);
        transform.center[0] += 1.0;
    }
}
```

# Tested Operating Systems
- [x] Windows 11 x86-64
- [x] Arch linux x86-64 (On wayland and gnome)
- [ ] Macos  

# Engine TODO

MIGRATED TO BASKET (https://github.com/Tofaa2/basket)

## Renderer
- [x] Restructure renderbatch and views to support proper optimizations for each type of renderable
- [x] Transient buffer support for per-frame geometry
- [x] Static mesh rendering
- [x] Dynamic mesh rendering
- [x] Material system (unlit + diffuse)
- [x] Directional lighting with Lambert diffuse
- [x] Multiple directional lights (up to 4)
- [x] Normals in vertex format
- [x] OBJ loading with MTL parser
- [x] Texture support for meshes (map_Kd)
- [x] Font rendering and text
- [x] 2D primitives (circle, rect, line, quad, triangle)
- [x] Anchor system for resolution-independent positioning
- [x] Separate 2D and 3D views with correct coordinate systems
- [ ] Cubemaps
- [ ] Point lights and spot lights
- [ ] Shadow mapping
- [x] Skybox / environment map
- [ ] Render passes and framebuffers
- [ ] Post-processing effects (bloom, blur, tonemapping)
- [ ] Sprite sheets and UV sub-regions
- [ ] Particle system
- [ ] Backface culling and other draw call optimizations
- [ ] Batch merging for same-texture 2D sprites
- [ ] Better pipeline with more configurable views
- [ ] GLTF model loading (required for animations)
- [ ] Skeletal animation

## UI
- [x] Basic immediate-mode UI context (rect, label, button)
- [x] Font rendering with correct baseline
- [x] Anchor system for screen-edge positioning
- [ ] Retained mode widget system (panel, list, tree, inspector)
- [ ] Text input widget
- [ ] Scrollable panels
- [ ] Nine-slice panel rendering for scalable UI backgrounds
- [ ] Proper alpha blending for UI (currently using discard)

## Input
- [x] Keyboard input (pressed, held, released)
- [x] Mouse position and delta
- [x] Mouse capture for FPS camera
- [x] Keybind system with callbacks
- [ ] Gamepad support
- [x] Mouse scroll wheel
- [x] Key modifier support (ctrl, shift, alt) in keybinds

## Camera
- [x] 2D orthographic camera with pixel coordinates
- [x] 3D perspective camera with FPS movement
- [x] Mouse look with pitch/yaw
- [x] Camera as ECS resource
- [ ] Orbit camera
- [x] Camera frustum culling

## ECS
- [x] Entity creation and destruction
- [x] Component add/get/remove
- [x] View queries with multiple components
- [x] Light as ECS component
- [x] Anchor as ECS component
- [x] Switch to in-house ECS
- [x] Component events (on_add, on_remove)
- [x] Entity parenting and hierarchies
- [x] ECS serialization

## Audio
- [x] Audio system integration
- [x] Play/stop/pause sounds
- [x] Looping background music
- [ ] 3D positional audio
- [x] Volume and pitch control
- [x] Audio as ECS component

## Physics
- [x] 2D AABB collision detection
- [x] 2D collision response
- [x] 3D collision detection
- [x] Rigidbody component
- [ ] Trigger volumes

## Serialization & Prefabs
- [x] Component serialization to JSON or custom binary format
- [x] Prefab file format (groups of entities with components)
- [x] Prefab runtime (spawn entities from prefab files)
- [x] Hot reload of prefab files

## Scene Editor
- [ ] Separate editor executable using engine as library
- [ ] 3D viewport with orbit camera
- [ ] Entity hierarchy panel
- [ ] Component inspector panel
- [ ] Asset browser
- [ ] Save/load prefab files
- [ ] Basic scripting API

## Engine & Utilities
- [x] App resource system
- [x] Scheduler with phases and priorities
- [x] Frame and generic allocators
- [x] Time and delta time
- [x] FPS counter with rolling average
- [x] FPS limiter
- [x] Window resize handling
- [x] Random number generation (currently timestamp-based, needs proper RNG)
- [x] Fix memory leaks (mostly shutdown logic)
- [ ] Proper error handling (replace unreachable with error propagation)
- [x] Documentation on all public APIs
- [x] CLI argument support (renderer backend selection etc)
- [x] Asset manager with reference counting
- [ ] Logging system with levels and categories
- [ ] Profiling and performance counters
- [x] Redo asset and resource approach completely, tighly couple specific areas
