const std = @import("std");

pub fn Scheduler(
    comptime Context: type,
    comptime Phases: type,
) type {
    const phases_info = @typeInfo(Phases);
    if (phases_info != .@"enum") {
        @compileError("Phases must be an enum");
    }
    const max_enum = phases_info.@"enum".fields.len;

    return struct {
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
        // Memory layout: A slice of structs containing only (ptr, len, capacity)
        stages: []StageList,

        fn always_run(_: *Context) bool {
            return true;
        }

        pub fn init(allocator: std.mem.Allocator) !Self {
            const stages = try allocator.alloc(StageList, max_enum);
            
            // Initialize each Unmanaged list to empty state (no allocation yet)
            for (stages) |*list| {
                list.* = .empty;
            }

            return .{
                .allocator = allocator,
                .stages = stages,
            };
        }

        pub fn deinit(self: *Self) void {
            // Explicitly pass the allocator to each list to free its internal buffer
            for (self.stages) |*list| {
                list.deinit(self.allocator);
            }
            // Free the top-level slice of lists
            self.allocator.free(self.stages);
        }

        pub fn addStage(self: *Self, stage: Stage) !void {
            const phase_index = @intFromEnum(stage.phase);
            const list = &self.stages[phase_index];

            // Explicitly provide the allocator for growth
            try list.append(self.allocator, stage);

            // Sort the internal items slice
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
    };
}
// const std = @import("std");
//
// pub fn Scheduler(
//     comptime Context: type,
//     comptime Phases: type,
// ) type {
//     const phases_info = @typeInfo(Phases);
//     if (phases_info != .@"enum") {
//         @compileError("Phases must be an enum");
//     }
//     const max_enum = phases_info.@"enum".fields.len;
//
//     return struct {
//         const Self = @This();
//
//         pub const Stage = struct {
//             name: []const u8,
//             priority: u8 = 0,
//             phase: Phases,
//             should_run: *const fn (*Context) bool = always_run,
//             run: *const fn (*Context) void,
//         };
//
//         allocator: std.mem.Allocator,
//         stages: [][]Stage,
//
//         fn always_run(_: *Context) bool {
//             return true;
//         }
//
//         pub fn init(config: struct {
//             allocator: std.mem.Allocator,
//             initial_size: usize = 24,
//         }) !Self {
//             const allocator = config.allocator;
//             const stages = try allocator.alloc([]Stage, max_enum);
//
//             // Initialize all phase arrays as empty
//             for (stages) |*phase_stages| {
//                 phase_stages.* = &[_]Stage{};
//             }
//
//             return .{
//                 .allocator = allocator,
//                 .stages = stages,
//             };
//         }
//
//         pub fn addStage(self: *Self, stage: Stage) !void {
//             const phase_index = @intFromEnum(stage.phase);
//             const current_stages = self.stages[phase_index];
//
//             const new_stages = try self.allocator.alloc(Stage, current_stages.len + 1);
//             @memcpy(new_stages[0..current_stages.len], current_stages);
//             new_stages[current_stages.len] = stage;
//             if (current_stages.len > 0) {
//                 self.allocator.free(current_stages);
//             }
//
//             self.stages[phase_index] = new_stages;
//
//             // Sort by priority (higher priority first)
//             std.mem.sort(Stage, new_stages, {}, struct {
//                 fn lessThan(_: void, a: Stage, b: Stage) bool {
//                     return a.priority > b.priority;
//                 }
//             }.lessThan);
//         }
//
//         pub fn deinit(self: *Self) void {
//             for (self.stages) |phase_stages| {
//                 if (phase_stages.len > 0) {
//                     self.allocator.free(phase_stages);
//                 }
//             }
//             self.allocator.free(self.stages);
//         }
//
//         pub fn run(self: *Self, context: *Context, phase: Phases) void {
//             const phase_index = @intFromEnum(phase);
//             for (self.stages[phase_index]) |stage| {
//                 if (stage.should_run(context)) {
//                     stage.run(context);
//                 }
//             }
//         }
//     };
// }
