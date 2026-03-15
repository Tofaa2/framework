const std = @import("std");
const TypeInfo = @import("type_id").TypeInfo;

pub const TypeErased = struct {
    ptr: *anyopaque,
    type_id: TypeInfo,
    // Store dependencies as IDs to resolve at runtime
    dependencies: []const usize,

    init: *const fn (*anyopaque, *anyopaque) void,
    deinit: *const fn (*anyopaque, *anyopaque) void,
    destroy: *const fn (*anyopaque, std.mem.Allocator) void,
};

pub const PluginError = error{
    DependencyNotFound,
    CircularDependency,
    AllocationFailed,
};

pub fn PluginManager(comptime Context: type) type {
    return struct {
        const Self = @This();

        plugins: std.ArrayList(TypeErased),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .plugins = .empty, // Keeping your preferred 0.15.x style
            };
        }

        pub fn deinit(self: *Self, context: *Context) void {
            // Deinit in REVERSE order of initialization (dependents first)
            var i: usize = self.plugins.items.len;
            while (i > 0) {
                i -= 1;
                const plugin = self.plugins.items[i];
                plugin.deinit(plugin.ptr, @as(*anyopaque, @ptrCast(context)));

                // Free the runtime dependency list and the plugin instance
                self.allocator.free(plugin.dependencies);
                plugin.destroy(plugin.ptr, self.allocator);
            }
            self.plugins.deinit(self.allocator);
        }

        /// Sorts and then initializes
        pub fn initPlugins(self: *Self, context: *Context) !void {
            try self.sortDependencies();

            for (self.plugins.items) |plugin| {
                plugin.init(plugin.ptr, context);
            }
        }

        fn sortDependencies(self: *Self) !void {
            const NodeState = enum { unvisited, visiting, visited };

            const states = try self.allocator.alloc(NodeState, self.plugins.items.len);
            defer self.allocator.free(states);
            @memset(states, .unvisited);

            var sorted_list = try std.ArrayList(TypeErased).initCapacity(self.allocator, self.plugins.items.len);
            errdefer sorted_list.deinit(self.allocator);

            // Mapping for quick lookup during DFS
            var type_map = std.AutoHashMap(usize, usize).init(self.allocator);
            defer type_map.deinit();
            for (self.plugins.items, 0..) |p, i| try type_map.put(p.type_id.id, i);

            const RecursiveSort = struct {
                fn visit(
                    idx: usize,
                    pm: *Self,
                    st: []NodeState,
                    map: *std.AutoHashMap(usize, usize),
                    out: *std.ArrayList(TypeErased),
                ) !void {
                    if (st[idx] == .visited) return;
                    if (st[idx] == .visiting) return error.CircularDependency;

                    st[idx] = .visiting;
                    const plugin = pm.plugins.items[idx];

                    for (plugin.dependencies) |dep_id| {
                        const dep_idx = map.get(dep_id) orelse return error.DependencyNotFound;
                        try visit(dep_idx, pm, st, map, out);
                    }

                    st[idx] = .visited;
                    try out.append(pm.allocator, plugin);
                }
            };

            for (0..self.plugins.items.len) |i| {
                if (states[i] == .unvisited) {
                    try RecursiveSort.visit(i, self, states, &type_map, &sorted_list);
                }
            }

            // Swap old unsorted list with the new sorted one
            self.plugins.deinit(self.allocator);
            self.plugins = sorted_list;
        }

        pub fn add(self: *Self, plugin: anytype) PluginError!void {
            const plugin_type = @TypeOf(plugin);

            // Capture dependency IDs into a heap-allocated slice
            var deps: std.ArrayList(usize) = .empty;
            errdefer deps.deinit(self.allocator);

            if (@hasDecl(plugin_type, "dependencies")) {
                inline for (plugin_type.dependencies) |DepType| {
                    deps.append(self.allocator, TypeInfo.get(DepType).id) catch return error.AllocationFailed;
                }
            }

            const heaped = self.allocator.create(plugin_type) catch return error.AllocationFailed;
            heaped.* = plugin;

            const func_wrapper = struct {
                pub fn init(inst: *anyopaque, context: *anyopaque) void {
                    const plugin_ptr: *plugin_type = @ptrCast(@alignCast(inst));
                    if (@hasDecl(plugin_type, "init")) plugin_ptr.init(@ptrCast(@alignCast(context)));
                }
                pub fn deinit(inst: *anyopaque, context: *anyopaque) void {
                    const plugin_ptr: *plugin_type = @ptrCast(@alignCast(inst));
                    if (@hasDecl(plugin_type, "deinit")) plugin_ptr.deinit(@ptrCast(@alignCast(context)));
                }
                pub fn destroy(inst: *anyopaque, allocator: std.mem.Allocator) void {
                    allocator.destroy(@as(*plugin_type, @ptrCast(@alignCast(inst))));
                }
            };
            const erased = TypeErased{
                .ptr = heaped,
                .type_id = TypeInfo.get(plugin_type),
                .dependencies = deps.toOwnedSlice(self.allocator) catch |err| {
                    self.allocator.destroy(heaped);
                    std.log.err("Failed to allocate erased dependencies: {s}", .{@errorName(err)});
                    return PluginError.AllocationFailed;
                },
                .init = func_wrapper.init,
                .deinit = func_wrapper.deinit,
                .destroy = func_wrapper.destroy,
            };

            self.plugins.append(self.allocator, erased) catch return error.AllocationFailed;
        }
    };
}

test "hello" {
    const allocator = std.testing.allocator;
    var c = C{};

    var pm = PluginManager(C).init(allocator);
    errdefer pm.deinit(&c);

    try pm.add(B{});
    try pm.add(A{});
    try pm.add(D{});

    try pm.initPlugins(&c);
    pm.deinit(&c);
}
const C = struct {};
const A = struct {
    pub fn init(_: *A, _: *C) void {
        std.debug.print("A\n", .{});
    }
};
const B = struct {
    pub const dependencies = .{D};

    pub fn init(_: *B, _: *C) void {
        std.debug.print("B\n", .{});
    }
};

pub const D = struct {
    // pub const dependencies = .{B};

    pub fn init(_: *D, _: *C) void {
        std.debug.print("D\n", .{});
    }
};
