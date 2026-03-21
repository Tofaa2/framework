const runtime = @import("runtime");
const std = @import("std");
const common = @import("common.zig");

const GRID_W = 20;
const GRID_H = 20;
const CELL_SIZE: f32 = 32.0;
const GRID_OFFSET_X: f32 = 100.0;
const GRID_OFFSET_Y: f32 = 100.0;

pub const GridPos = struct {
    x: i32,
    y: i32,
};

pub const SnakeSegment = struct {
    next: ?runtime.ecs.Entity = null,
};

pub const SnakeHead = struct {
    dir_x: i32 = 1,
    dir_y: i32 = 0,
    next_dir_x: i32 = 1,
    next_dir_y: i32 = 0,
    move_timer: f32 = 0,
    move_interval: f32 = 0.15,
};

pub const Food = struct {};

pub const Score = struct {
    value: u32 = 0,
};

pub const GameState = enum {
    playing,
    game_over,
};

var score_buf: [32]u8 = undefined;
var game_over_buf: [64]u8 = undefined;
var fps_buf: [32]u8 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var app = runtime.App.init(.{
        .name = "snake",
        .allocators = .{
            .frame = arena_allocator,
            .generic = allocator,
            .world = allocator,
            .frame_arena = arena,
        },
    });
    defer app.deinit();

    var font = runtime.primitive.Font.initFile("assets/Roboto-Regular.ttf", 32, 512);
    defer font.deinit();

    common.setFPSMax(&app, 60);
    try app.resources.add(Score{});
    try app.resources.add(GameState.playing);

    // grid background
    const grid_bg = app.world.create();
    app.world.add(grid_bg, runtime.primitive.Transform{
        .center = .{
            GRID_OFFSET_X + (GRID_W * CELL_SIZE) / 2.0,
            GRID_OFFSET_Y + (GRID_H * CELL_SIZE) / 2.0,
            0,
        },
    });
    app.world.add(grid_bg, runtime.primitive.Renderable{ .rect = .{
        .width = GRID_W * CELL_SIZE,
        .height = GRID_H * CELL_SIZE,
    } });
    app.world.add(grid_bg, runtime.primitive.Color{ .r = 40, .g = 40, .b = 40, .a = 255 });

    spawnSnake(&app);
    spawnFood(&app);

    // fps counter
    const fps_label = app.world.create();
    app.world.add(fps_label, runtime.primitive.Transform{});
    app.world.add(fps_label, runtime.primitive.Anchor{ .point = .top_right, .offset = .{ -150.0, 10.0 } });
    app.world.add(fps_label, runtime.primitive.Renderable{ .fmt_text = .{
        .font = &font,
        .buf = &fps_buf,
        .format_fn = struct {
            fn f(buf: []u8, a: *runtime.App) []u8 {
                const fps = a.time.fps.fps;
                return std.fmt.bufPrint(buf, "FPS: {d:.0}", .{fps}) catch buf[0..0];
            }
        }.f,
    } });

    // score counter
    const score_label = app.world.create();
    app.world.add(score_label, runtime.primitive.Transform{});
    app.world.add(score_label, runtime.primitive.Anchor{ .point = .top_left, .offset = .{ 10.0, 10.0 } });
    app.world.add(score_label, runtime.primitive.Renderable{ .fmt_text = .{
        .font = &font,
        .buf = &score_buf,
        .format_fn = struct {
            fn f(buf: []u8, a: *runtime.App) []u8 {
                const score = a.resources.get(Score).?.value;
                return std.fmt.bufPrint(buf, "Score: {d}", .{score}) catch buf[0..0];
            }
        }.f,
    } });

    // game over label
    const game_over_label = app.world.create();
    app.world.add(game_over_label, runtime.primitive.Transform{});
    app.world.add(game_over_label, runtime.primitive.Anchor{ .point = .center, .offset = .{ -280.0, -20.0 } });
    app.world.add(game_over_label, runtime.primitive.Renderable{ .fmt_text = .{
        .font = &font,
        .buf = &game_over_buf,
        .format_fn = struct {
            fn f(buf: []u8, a: *runtime.App) []u8 {
                const state = a.resources.get(GameState).?;
                if (state.* == .game_over) {
                    const score = a.resources.get(Score).?.value;
                    return std.fmt.bufPrint(buf, "Game Over! Score: {d} - Press Enter to restart", .{score}) catch buf[0..0];
                }
                return buf[0..0];
            }
        }.f,
    } });

    try app.scheduler.addStage(.{
        .name = "update-keyboard",
        .phase = .update,
        .run = updateLoop,
    });
    try app.scheduler.addStage(.{
        .name = "update-transforms",
        .phase = .update,
        .run = updateTransforms,
        .priority = 100,
    });
    try app.scheduler.addStage(.{
        .name = "update-snake",
        .phase = .update,
        .run = updateSnake,
        .priority = 80,
    });

    app.run();
}
fn gridToWorld(gx: i32, gy: i32) [2]f32 {
    return .{
        GRID_OFFSET_X + @as(f32, @floatFromInt(gx)) * CELL_SIZE + CELL_SIZE / 2.0,
        GRID_OFFSET_Y + @as(f32, @floatFromInt(gy)) * CELL_SIZE + CELL_SIZE / 2.0,
    };
}

fn resetSnake(app: *runtime.App) void {
    // destroy all snake segments
    var query = app.world.view(.{SnakeSegment}, .{});
    var iter = query.entityIterator();
    var to_delete = std.ArrayList(runtime.ecs.Entity).initCapacity(app.allocators.generic, 8) catch unreachable;
    defer to_delete.deinit(app.allocators.generic);
    while (iter.next()) |entity| {
        to_delete.append(app.allocators.generic, entity) catch unreachable;
    }
    for (to_delete.items) |entity| {
        app.world.destroy(entity);
    }
    // spawn fresh snake
    spawnSnake(app);
}

fn updateLoop(app: *runtime.App) void {
    const win = app.resources.getMut(runtime.platform.Window).?;
    const state = app.resources.getMut(GameState).?;
    if (state.* == .game_over) {
        if (win.isKeyPressed(.@"return")) {
            state.* = .playing;
            app.resources.getMut(Score).?.value = 0;
            resetSnake(app);
            // reset food
            var fq = app.world.view(.{ GridPos, Food }, .{});
            var fi = fq.entityIterator();
            if (fi.next()) |fe| {
                const fp = fq.get(GridPos, fe);
                fp.x = 15;
                fp.y = 10;
            }
        }
        return;
    }
    // if (state.* == .game_over) {
    //     if (win.isKeyPressed(.@"return")) {
    //         state.* = .playing;
    //         app.resources.getMut(Score).?.value = 0;
    //         // reset head position and direction
    //         var sq = app.world.view(.{ GridPos, SnakeHead }, .{});
    //         var si = sq.entityIterator();
    //         if (si.next()) |he| {
    //             const hp = sq.get(GridPos, he);
    //             const hd = sq.get(SnakeHead, he);
    //             hp.x = 10;
    //             hp.y = 10;
    //             hd.dir_x = 1;
    //             hd.dir_y = 0;
    //             hd.next_dir_x = 1;
    //             hd.next_dir_y = 0;
    //             hd.move_timer = 0;
    //         }
    //         // reset food
    //         var fq = app.world.view(.{ GridPos, Food }, .{});
    //         var fi = fq.entityIterator();
    //         if (fi.next()) |fe| {
    //             const fp = fq.get(GridPos, fe);
    //             fp.x = 15;
    //             fp.y = 10;
    //         }
    //     }
    //     return;
    // }

    var query = app.world.view(.{SnakeHead}, .{});
    var iter = query.entityIterator();
    const head_entity = iter.next() orelse return;
    const head = query.get(head_entity);

    if (win.isKeyPressed(.up) and head.dir_y == 0) {
        head.next_dir_x = 0;
        head.next_dir_y = -1;
    }
    if (win.isKeyPressed(.down) and head.dir_y == 0) {
        head.next_dir_x = 0;
        head.next_dir_y = 1;
    }
    if (win.isKeyPressed(.left) and head.dir_x == 0) {
        head.next_dir_x = -1;
        head.next_dir_y = 0;
    }
    if (win.isKeyPressed(.right) and head.dir_x == 0) {
        head.next_dir_x = 1;
        head.next_dir_y = 0;
    }
}

fn spawnSnake(app: *runtime.App) void {
    const tail = app.world.create();
    app.world.add(tail, GridPos{ .x = 8, .y = 10 });
    app.world.add(tail, SnakeSegment{ .next = null });
    app.world.add(tail, runtime.primitive.Transform{});
    app.world.add(tail, runtime.primitive.Renderable{ .rect = .{ .width = CELL_SIZE - 2, .height = CELL_SIZE - 2 } });
    app.world.add(tail, runtime.primitive.Color{ .r = 0, .g = 200, .b = 0, .a = 255 });

    const mid = app.world.create();
    app.world.add(mid, GridPos{ .x = 9, .y = 10 });
    app.world.add(mid, SnakeSegment{ .next = tail });
    app.world.add(mid, runtime.primitive.Transform{});
    app.world.add(mid, runtime.primitive.Renderable{ .rect = .{ .width = CELL_SIZE - 2, .height = CELL_SIZE - 2 } });
    app.world.add(mid, runtime.primitive.Color{ .r = 0, .g = 200, .b = 0, .a = 255 });

    const head = app.world.create();
    app.world.add(head, GridPos{ .x = 10, .y = 10 });
    app.world.add(head, SnakeSegment{ .next = mid });
    app.world.add(head, SnakeHead{});
    app.world.add(head, runtime.primitive.Transform{});
    app.world.add(head, runtime.primitive.Renderable{ .rect = .{ .width = CELL_SIZE - 2, .height = CELL_SIZE - 2 } });
    app.world.add(head, runtime.primitive.Color{ .r = 0, .g = 255, .b = 0, .a = 255 });
}

fn spawnFood(app: *runtime.App) void {
    const food = app.world.create();
    app.world.add(food, GridPos{ .x = 15, .y = 10 });
    app.world.add(food, Food{});
    app.world.add(food, runtime.primitive.Transform{});
    app.world.add(food, runtime.primitive.Renderable{ .rect = .{ .width = CELL_SIZE - 2, .height = CELL_SIZE - 2 } });
    app.world.add(food, runtime.primitive.Color{ .r = 255, .g = 0, .b = 0, .a = 255 });
}

fn updateTransforms(app: *runtime.App) void {
    var query = app.world.view(.{ GridPos, runtime.primitive.Transform }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const pos = query.getConst(GridPos, entity);
        const transform = query.get(runtime.primitive.Transform, entity);
        const world = gridToWorld(pos.x, pos.y);
        transform.center[0] = world[0];
        transform.center[1] = world[1];
    }
}

fn isOccupiedBySnake(app: *runtime.App, x: i32, y: i32) bool {
    var query = app.world.view(.{ GridPos, SnakeSegment }, .{});
    var iter = query.entityIterator();
    while (iter.next()) |entity| {
        const pos = query.getConst(GridPos, entity);
        if (pos.x == x and pos.y == y) return true;
    }
    return false;
}

fn updateSnake(app: *runtime.App) void {
    const state = app.resources.get(GameState).?;
    if (state.* == .game_over) return;

    const time = app.resources.get(runtime.primitive.Time).?;
    const dt: f32 = @floatCast(time.delta);

    var query = app.world.view(.{ GridPos, SnakeSegment, SnakeHead }, .{});
    var iter = query.entityIterator();
    const head_entity = iter.next() orelse return;

    const head = query.get(SnakeHead, head_entity);
    head.move_timer += dt;
    if (head.move_timer < head.move_interval) return;
    head.move_timer = 0;

    head.dir_x = head.next_dir_x;
    head.dir_y = head.next_dir_y;

    var segments = std.ArrayList(runtime.ecs.Entity).initCapacity(app.allocators.frame, 5) catch unreachable;
    defer segments.deinit(app.allocators.frame);

    const head_pos = query.getConst(GridPos, head_entity);
    var seg_query = app.world.view(.{ GridPos, SnakeSegment }, .{});

    segments.append(app.allocators.frame, head_entity) catch unreachable;
    var seg = query.getConst(SnakeSegment, head_entity);
    while (seg.next) |next| {
        segments.append(app.allocators.frame, next) catch unreachable;
        seg = seg_query.getConst(SnakeSegment, next);
    }

    var i = segments.items.len;
    while (i > 1) {
        i -= 1;
        const behind = seg_query.get(GridPos, segments.items[i]);
        const ahead = seg_query.getConst(GridPos, segments.items[i - 1]);
        behind.x = ahead.x;
        behind.y = ahead.y;
    }

    const head_pos_mut = query.get(GridPos, head_entity);
    head_pos_mut.x = head_pos.x + head.dir_x;
    head_pos_mut.y = head_pos.y + head.dir_y;

    // wall collision
    if (head_pos_mut.x < 0 or head_pos_mut.x >= GRID_W or
        head_pos_mut.y < 0 or head_pos_mut.y >= GRID_H)
    {
        app.resources.getMut(GameState).?.* = .game_over;
        return;
    }

    // self collision
    for (segments.items[1..]) |seg_entity| {
        const seg_pos = seg_query.getConst(GridPos, seg_entity);
        if (seg_pos.x == head_pos_mut.x and seg_pos.y == head_pos_mut.y) {
            app.resources.getMut(GameState).?.* = .game_over;
            return;
        }
    }

    // food collision
    var food_query = app.world.view(.{ GridPos, Food }, .{});
    var food_iter = food_query.entityIterator();
    while (food_iter.next()) |food_entity| {
        const food_pos = food_query.get(GridPos, food_entity);
        if (food_pos.x == head_pos_mut.x and food_pos.y == head_pos_mut.y) {
            var rand_x: i32 = 0;
            var rand_y: i32 = 0;
            var seed = std.time.timestamp();
            while (true) {
                rand_x = @mod(@as(i32, @intCast(seed)), GRID_W);
                rand_y = @mod(@as(i32, @intCast(@divTrunc(seed, 7))), GRID_H);
                if (!isOccupiedBySnake(app, rand_x, rand_y)) break;
                seed += 1;
            }
            food_pos.x = rand_x;
            food_pos.y = rand_y;

            const tail_entity = segments.items[segments.items.len - 1];
            const tail_pos = seg_query.getConst(GridPos, tail_entity);
            const tail_seg = seg_query.get(SnakeSegment, tail_entity);
            const new_tail = app.world.create();
            app.world.add(new_tail, GridPos{ .x = tail_pos.x, .y = tail_pos.y });
            app.world.add(new_tail, SnakeSegment{ .next = null });
            app.world.add(new_tail, runtime.primitive.Transform{});
            app.world.add(new_tail, runtime.primitive.Renderable{ .rect = .{ .width = CELL_SIZE - 2, .height = CELL_SIZE - 2 } });
            app.world.add(new_tail, runtime.primitive.Color{ .r = 0, .g = 200, .b = 0, .a = 255 });
            tail_seg.next = new_tail;

            app.resources.getMut(Score).?.value += 1;
        }
    }
}

