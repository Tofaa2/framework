const runtime = @import("runtime");
const std = @import("std");

const AppState = struct {
    bunny_mesh: runtime.Handle(runtime.Mesh),
    randomness: f32 = 2.0,
    prng: std.Random.DefaultPrng,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try runtime.App.init(allocator, .{
        .name = "Physics Demo",
        .width = 1280,
        .height = 720,
    });
    defer app.deinit();

    app.time.fps_limit = 165;
    app.window.setMouseCaptured(true);

    const player = app.world.create();
    app.world.add(player, runtime.Camera3D.init());
    var cam = app.world.get(runtime.Camera3D, player);
    cam.position = .{ 0, 5, 15, 1 };
    cam.yaw = -std.math.pi / 2.0;
    cam.pitch = -0.3;
    setupCamera(app);

    const sun = app.world.create();
    app.world.add(sun, runtime.Transform{ .rotation = .{ 0.6, -0.8, 0.2 } });
    app.world.add(sun, runtime.Light{ .color = .white, .intensity = 1.2 });

    const bunny_mesh = try app.assets.loadMesh("assets/animal-bunny.obj", &app.renderer.vertex_layout);
    try app.resources.add(AppState{ 
        .bunny_mesh = bunny_mesh,
        .prng = std.Random.DefaultPrng.init(0),
    });

    var builder = runtime.MeshBuilder.init(allocator);
    builder.pushCube(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, runtime.Color.white);
    const floor_mesh_raw = builder.buildMesh(&app.renderer.vertex_layout);
    const floor_mesh_handle = try app.assets.loadAsset(runtime.Mesh, floor_mesh_raw);
    builder.deinit();

    // Box constraints: [Floor, Ceiling, Left, Right, Back, Front]
    const BoxWall = struct { center: [3]f32, size: [3]f32 };
    const walls = [_]BoxWall{
        .{ .center = .{ 0.0, -2.0, 0.0 }, .size = .{ 40.0, 0.5, 40.0 } }, // Floor
        .{ .center = .{ 0.0, 20.0, 0.0 }, .size = .{ 40.0, 0.5, 40.0 } }, // Ceiling
        .{ .center = .{ -20.0, 9.0, 0.0 }, .size = .{ 0.5, 22.0, 40.0 } }, // Left
        .{ .center = .{ 20.0, 9.0, 0.0 }, .size = .{ 0.5, 22.0, 40.0 } }, // Right
        .{ .center = .{ 0.0, 9.0, -20.0 }, .size = .{ 40.0, 22.0, 0.5 } }, // Back
        .{ .center = .{ 0.0, 9.0, 20.0 }, .size = .{ 40.0, 22.0, 0.5 } }, // Front
    };

    for (walls) |wall| {
        const floor = app.world.create();
        app.world.add(floor, runtime.Transform{
            .center = wall.center,
            .size = wall.size,
        });
        app.world.add(floor, runtime.Renderable{ .mesh = .{ .mesh = floor_mesh_handle } });
        app.world.add(floor, runtime.RigidBody{ .is_static = true, .restitution = 1.0 });
        app.world.add(floor, runtime.Collider{ 
            .half_extents = .{ wall.size[0] / 2.0, wall.size[1] / 2.0, wall.size[2] / 2.0 } 
        });
    }

    std.log.info("Starting Physics Demo...", .{});

    // --- Falling Bunnies ------------------------------------------------
    const count = 5;
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const x = @as(f32, @floatFromInt(i)) * 2.0 - 4.0;
        const y = 5.0 + @as(f32, @floatFromInt(i)) * 2.0;

        const bunny = app.world.create();
        app.world.add(bunny, runtime.Transform{
            .center = .{ x, y, 0.0 },
            .size = .{ 1.0, 1.0, 1.0 },
        });
        app.world.add(bunny, runtime.Renderable{ .mesh = .{ .mesh = bunny_mesh } });
        app.world.add(bunny, runtime.RigidBody{
            .mass = 1.0,
            .restitution = 0.8,
        });
        app.world.add(bunny, runtime.Velocity{});
        app.world.add(bunny, runtime.Gravity{});
        app.world.add(bunny, runtime.Collider{
            .half_extents = .{ 0.5, 0.5, 0.5 },
            .offset = .{ 0.0, -0.4, 0.0 },
        });
    }

    // --- Labels -----------------------------------------------------
    const font = try app.assets.loadAsset(runtime.Font, runtime.Font.initFile("assets/Roboto-Regular.ttf", 24, 512));
    const fps_label = app.world.create();
    app.world.add(fps_label, runtime.Transform{});
    app.world.add(fps_label, runtime.Anchor{ .point = .top_left, .offset = .{ 10, 10 } });
    app.world.add(fps_label, runtime.Renderable{ .fmt_text = .{
        .font = font,
        .buf = &[_]u8{},
        .format_fn = struct {
            fn f(_: []u8, appl: *runtime.App) []u8 {
                return std.fmt.allocPrint(appl.getFrameAllocator(), "FPS: {d:.0}", .{appl.time.fps.fps}) catch "";
            }
        }.f,
    } });

    const tip_label = app.world.create();
    app.world.add(tip_label, runtime.Transform{});
    app.world.add(tip_label, runtime.Anchor{ .point = .top_left, .offset = .{ 10, 40 } });
    app.world.add(tip_label, runtime.Renderable{ .fmt_text = .{
        .font = font,
        .buf = &[_]u8{},
        .format_fn = struct {
            fn f(_: []u8, appl: *runtime.App) []u8 {
                return std.fmt.allocPrint(appl.getFrameAllocator(), "Press Left Click to throw a bunny", .{}) catch "";
            }
        }.f,
    } });

    app.run();
}

fn findCam(app: *runtime.App) ?*runtime.Camera3D {
    var view = app.world.basicView(runtime.Camera3D);
    var it = view.mutIterator();
    return it.next();
}

fn setupCamera(app: *runtime.App) void {
    app.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const appl: *runtime.App = @ptrCast(@alignCast(world.ctx.?));
            if (findCam(appl)) |cam| {
                appl.renderer.getView(.@"3d").?.view_mtx = cam.getViewMatrix();
            }
        }
    }.f)
        .reads(runtime.Camera3D)
        .inPhase(.pre_update)
        .append();

    app.world.scheduler.buildSystem(struct {
        fn f(world: *runtime.World) void {
            const appl: *runtime.App = @ptrCast(@alignCast(world.ctx.?));
            const cam = findCam(appl) orelse return;
            
            // Mouse look
            const delta = appl.window.getMouseDelta();
            if (delta[0] != 0 or delta[1] != 0) cam.rotate(delta[0], delta[1]);
            
            // Throw bunny on click
            if (appl.window.isMousePressed(.left)) {
                const state = appl.resources.getMut(AppState) orelse return;
                const bunny = appl.world.create();
                appl.world.add(bunny, runtime.Transform{
                    .center = .{ cam.position[0], cam.position[1], cam.position[2] },
                    .size = .{ 1.0, 1.0, 1.0 },
                });
                appl.world.add(bunny, runtime.Renderable{ .mesh = .{ .mesh = state.bunny_mesh } });
                
                const forward = cam.forwardDir();
                const speed = 25.0; // Throw speed
                
                const r_val = state.randomness;
                var rand = state.prng.random();
                const jx = (rand.float(f32) * 2.0 - 1.0) * r_val;
                const jy = (rand.float(f32) * 2.0 - 1.0) * r_val;
                const jz = (rand.float(f32) * 2.0 - 1.0) * r_val;

                appl.world.add(bunny, runtime.RigidBody{
                    .mass = 1.0,
                    .restitution = 0.8, // Bouncy
                });
                appl.world.add(bunny, runtime.Velocity{
                    .value = .{ forward[0] * speed + jx, forward[1] * speed + jy, forward[2] * speed + jz },
                });
                appl.world.add(bunny, runtime.Gravity{});
                appl.world.add(bunny, runtime.Collider{
                    .half_extents = .{ 0.5, 0.5, 0.5 },
                    .offset = .{ 0.0, -0.4, 0.0 },
                });
            }
        }
    }.f)
        .writes(runtime.Camera3D)
        .inPhase(.pre_update)
        .append();

    app.keybinds.bind(.{ .key = .w, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveForward(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .s, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveBackward(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .a, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveLeft(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .d, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveRight(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .space, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveUp(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .shiftL, .on_held = struct {
        fn f(appl: *runtime.App) void {
            findCam(appl).?.moveDown(@floatCast(appl.time.delta));
        }
    }.f });
    app.keybinds.bind(.{ .key = .escape, .on_press = struct {
        fn f(appl: *runtime.App) void {
            appl.window.setMouseCaptured(false);
        }
    }.f });

    app.keybinds.bind(.{ .key = .equal, .on_press = struct {
        fn f(appl: *runtime.App) void {
            if (appl.resources.getMut(AppState)) |state| {
                state.randomness += 2.0;
                std.log.info("Throw Randomness set to: {d:.1}", .{state.randomness});
            }
        }
    }.f });
    
    app.keybinds.bind(.{ .key = .minus, .on_press = struct {
        fn f(appl: *runtime.App) void {
            if (appl.resources.getMut(AppState)) |state| {
                state.randomness = @max(0.0, state.randomness - 2.0);
                std.log.info("Throw Randomness set to: {d:.1}", .{state.randomness});
            }
        }
    }.f });
}
