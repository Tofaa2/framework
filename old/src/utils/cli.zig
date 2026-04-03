const std = @import("std");

pub fn parseArgs(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !*T {
    var allocated = try allocator.create(T);
    const type_info = @typeInfo(T);

    for (args) |arg| {
        var spliterator = std.mem.splitAny(u8, arg, "=");
        const name = spliterator.next();
        const value = spliterator.next();
        if (name == null) {
            break;
        }
        if (value == null) {
            std.log.err("No value provided for cli argument {?s}", .{name});
            continue;
        }

        inline for (type_info.@"struct".fields) |field| {
            if (std.mem.eql(u8, name.?, field.name)) {
                const field_value = switch (field.type) {
                    std.mem.Allocator => allocator,
                    []const u8 => value.?,
                    i64 => std.fmt.parseInt(i64, value.?, 10) catch 0,
                    f64 => std.fmt.parseFloat(f64, value.?) catch 0,
                    else => continue,
                };
                @field(allocated, field.name) = field_value;
            }
        }
    }

    return allocated;
}

const MyOptions = struct {
    name: []const u8,
    age: i64,
};

test "cli" {
    const args: []const []const u8 = &.{ "--name=Amogus", "--age=69" };

    const options = try parseArgs(MyOptions, std.testing.allocator, args);
    defer std.testing.allocator.destroy(options);

    try std.testing.expectEqualStrings("Amogus", options.name);
    try std.testing.expectEqual(@as(i64, 69), options.age);
}
