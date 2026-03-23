const std = @import("std");
const Context = @import("App.zig");
pub const Phases = enum {
    init,
    deinit,
    update,
    input,
    render,
    physics,
};

const Self = @This();
const StageList = std.ArrayListUnmanaged(Stage);

pub const Stage = struct {
    name: []const u8,
    priority: u8 = 0,
    phase: Phases,
    should_run: *const fn (*Context) bool = always_run,
    run: *const fn (*Context) void,
};

allocator: std.mem.Allocator,
stages: []StageList,

fn always_run(_: *Context) bool {
    return true;
}

pub fn init(allocator: std.mem.Allocator) !*Self {
    const max_enum = @typeInfo(Phases).@"enum".fields.len;
    const stages = try allocator.alloc(StageList, max_enum);

    for (stages) |*list| {
        list.* = .empty;
    }

    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator,
        .stages = stages,
    };
    return self;
}

pub fn deinit(self: *Self) void {
    for (self.stages) |*list| {
        list.deinit(self.allocator);
    }
    self.allocator.free(self.stages);
    self.allocator.destroy(self);
}

pub fn addStage(self: *Self, stage: Stage) !void {
    const phase_index = @intFromEnum(stage.phase);
    const list = &self.stages[phase_index];

    try list.append(self.allocator, stage);

    std.mem.sort(Stage, list.items, {}, struct {
        fn lessThan(_: void, a: Stage, b: Stage) bool {
            return a.priority > b.priority;
        }
    }.lessThan);
}

pub fn run(self: *Self, context: *Context, phase: Phases) void {
    const phase_index = @intFromEnum(phase);
    const list = self.stages[phase_index];

    for (list.items) |stage| {
        if (stage.should_run(context)) {
            stage.run(context);
        }
    }
}
