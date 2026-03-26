const std = @import("std");
const root = @import("../root.zig");

pub const Event = union(enum) {
    window_resize: struct {
        old_width: u32,
        new_width: u32,
        old_height: u32,
        new_height: u32,
    },
    entity_create: struct {
        entity: root.Entity,
    },
    entity_destroy: struct {
        entity: root.Entity,
    },
    update,
};

pub const EventManager = GenericEventManager(Event);

pub fn GenericEventManager(
    comptime EventUnion: type,
) type {
    comptime {
        const type_info = @typeInfo(EventUnion);
        if (type_info != .@"union") {
            @compileError("EventManager requires a union of events supplied as EventUnion parameter");
        }
        if (type_info.@"union".tag_type == null) {
            @compileError("EventUnion must be a tagged union (e.g., union(enum)) to dispatch active events at runtime.");
        }
    }
    return struct {
        const Self = @This();
        const EventTag = std.meta.Tag(EventUnion);

        pub fn Listener(comptime PayloadType: type) type {
            return struct {
                callback: *const fn (ctx: ?*anyopaque, payload: PayloadType) void,
                ctx: ?*anyopaque,
            };
        }

        const Listeners = blk: {
            const fields = @typeInfo(EventUnion).@"union".fields;
            var struct_fields: [fields.len]std.builtin.Type.StructField = undefined;

            for (fields, 0..) |field, i| {
                const ListType = std.ArrayList(Listener(field.type));
                struct_fields[i] = .{
                    .name = field.name,
                    .type = ListType,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(ListType),
                };
            }

            break :blk @Type(.{ .@"struct" = .{
                .layout = .auto,
                .fields = &struct_fields,
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            } });
        };

        allocator: std.mem.Allocator,
        listeners: *Listeners,

        pub fn init(allocator: std.mem.Allocator) *Self {
            var listeners = allocator.create(Listeners) catch unreachable;

            inline for (@typeInfo(EventUnion).@"union".fields) |field| {
                @field(listeners, field.name) = .empty; //  std.ArrayList(Listener(field.type)).init(allocator);
            }

            const self = allocator.create(Self) catch unreachable;
            self.* = .{
                .allocator = allocator,
                .listeners = listeners,
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            inline for (@typeInfo(EventUnion).@"union".fields) |field| {
                @field(self.listeners, field.name).deinit(self.allocator);
            }
            self.allocator.destroy(self.listeners);
            self.allocator.destroy(self);
        }

        /// Subscribe to a specific event tag
        pub fn subscribe(
            self: *Self,
            comptime tag: EventTag,
            ctx: ?*anyopaque,
            callback: *const fn (?*anyopaque, std.meta.TagPayload(EventUnion, tag)) void,
        ) !void {
            try @field(self.listeners, @tagName(tag)).append(self.allocator, .{
                .callback = callback,
                .ctx = ctx,
            });
        }

        /// Unsubscribe a previously registered callback
        pub fn unsubscribe(
            self: *Self,
            comptime tag: EventTag,
            ctx: ?*anyopaque,
            callback: *const fn (?*anyopaque, std.meta.TagPayload(EventUnion, tag)) void,
        ) void {
            var list = &@field(self.listeners, @tagName(tag));
            var i: usize = 0;
            while (i < list.items.len) {
                const item = list.items[i];
                if (item.callback == callback and item.ctx == ctx) {
                    _ = list.swapRemove(i);
                    // Do not increment `i` so we evaluate the newly swapped element
                } else {
                    i += 1;
                }
            }
        }

        /// Dispatch an event to all subscribed listeners
        pub fn dispatch(self: *Self, event: EventUnion) void {
            const active_tag = std.meta.activeTag(event);

            inline for (@typeInfo(EventUnion).@"union".fields) |field| {
                if (@field(EventTag, field.name) == active_tag) {
                    const payload = @field(event, field.name);
                    for (@field(self.listeners, field.name).items) |listener| {
                        listener.callback(listener.ctx, payload);
                    }
                }
            }
        }
    };
}
