const std = @import("std");
const builtin = @import("builtin");

pub const queue = @import("queue.zig");


pub fn ansiCode(comptime code: u8) []const u8 {
    return std.fmt.comptimePrint("\x1b[{d}m", .{code});
}

pub const Ansi = struct {
    // Reset
    pub const reset         = ansiCode(0);

    // Text styles
    pub const bold          = ansiCode(1);
    pub const dim           = ansiCode(2);
    pub const italic        = ansiCode(3);
    pub const underline     = ansiCode(4);
    pub const blink         = ansiCode(5);
    pub const blink_rapid   = ansiCode(6);
    pub const reverse       = ansiCode(7);
    pub const conceal       = ansiCode(8);
    pub const strikethrough = ansiCode(9);

    // Reset styles
    pub const bold_off          = ansiCode(22);
    pub const italic_off        = ansiCode(23);
    pub const underline_off     = ansiCode(24);
    pub const blink_off         = ansiCode(25);
    pub const reverse_off       = ansiCode(27);
    pub const conceal_off       = ansiCode(28);
    pub const strikethrough_off = ansiCode(29);

    // Foreground colors (standard)
    pub const fg_black   = ansiCode(30);
    pub const fg_red     = ansiCode(31);
    pub const fg_green   = ansiCode(32);
    pub const fg_yellow  = ansiCode(33);
    pub const fg_blue    = ansiCode(34);
    pub const fg_magenta = ansiCode(35);
    pub const fg_cyan    = ansiCode(36);
    pub const fg_white   = ansiCode(37);
    pub const fg_default = ansiCode(39);

    // Background colors (standard)
    pub const bg_black   = ansiCode(40);
    pub const bg_red     = ansiCode(41);
    pub const bg_green   = ansiCode(42);
    pub const bg_yellow  = ansiCode(43);
    pub const bg_blue    = ansiCode(44);
    pub const bg_magenta = ansiCode(45);
    pub const bg_cyan    = ansiCode(46);
    pub const bg_white   = ansiCode(47);
    pub const bg_default = ansiCode(49);

    // Foreground colors (bright)
    pub const fg_bright_black   = ansiCode(90);
    pub const fg_bright_red     = ansiCode(91);
    pub const fg_bright_green   = ansiCode(92);
    pub const fg_bright_yellow  = ansiCode(93);
    pub const fg_bright_blue    = ansiCode(94);
    pub const fg_bright_magenta = ansiCode(95);
    pub const fg_bright_cyan    = ansiCode(96);
    pub const fg_bright_white   = ansiCode(97);

    // Background colors (bright)
    pub const bg_bright_black   = ansiCode(100);
    pub const bg_bright_red     = ansiCode(101);
    pub const bg_bright_green   = ansiCode(102);
    pub const bg_bright_yellow  = ansiCode(103);
    pub const bg_bright_blue    = ansiCode(104);
    pub const bg_bright_magenta = ansiCode(105);
    pub const bg_bright_cyan    = ansiCode(106);
    pub const bg_bright_white   = ansiCode(107);

    // 256-color support (now possible with comptime!)
    pub fn fg256(comptime n: u8) []const u8 {
        return std.fmt.comptimePrint("\x1b[38;5;{d}m", .{n});
    }
    pub fn bg256(comptime n: u8) []const u8 {
        return std.fmt.comptimePrint("\x1b[48;5;{d}m", .{n});
    }

    // True color / RGB support
    pub fn fgRgb(comptime r: u8, comptime g: u8, comptime b: u8) []const u8 {
        return std.fmt.comptimePrint("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
    }
    pub fn bgRgb(comptime r: u8, comptime g: u8, comptime b: u8) []const u8 {
        return std.fmt.comptimePrint("\x1b[48;2;{d};{d};{d}m", .{ r, g, b });
    }
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (comptime builtin.mode == .ReleaseFast) {
        return;
    }

    const color = switch (level) {
        .err => Ansi.fg_red,
        .warn => Ansi.fg_yellow,
        .info => Ansi.fg_blue,
        .debug => Ansi.fg_green,
    };

    const scope_prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    var buffer: [256]u8 = undefined;
    const stderr = std.debug.lockStderrWriter(&buffer);
    defer std.debug.unlockStderrWriter();

    stderr.print(color ++ prefix ++ format ++ Ansi.reset ++ "\n", args) catch return;
}

fn TPtr(T: type, opaque_ptr: *anyopaque) T {
    return @as(T, @ptrCast(@alignCast(opaque_ptr)));
}

/// The runtime-available representation of a Zig type.
pub const TypeInfo = struct {
    name: []const u8,
    id: usize,
    size: usize,
    alignment: usize,

    /// Returns the TypeInfo for any given type T at compile-time.
    pub fn get(comptime T: type) TypeInfo {
        return .{
            .name = @typeName(T),
            // The compiler creates a unique instance of this struct for every 'T'
            .id = @intFromEnum(typeId(T)),
            .size = @sizeOf(T),
            .alignment = @alignOf(T),
        };
    }
};

const TypeId = enum(usize) {
    _,

    pub fn name(self: TypeId) []const u8 {
        if (builtin.mode == .Debug) {
            return std.mem.sliceTo(@as([*:0]const u8, @ptrFromInt(@intFromEnum(self))), 0);
        } else {
            @compileError("Cannot use TypeId.name outside of Debug mode!");
        }
    }
};

fn typeId(comptime T: type) TypeId {
    const Tag = struct {
        var name: u8 = @typeName(T)[0]; // must depend on the type somehow!
        inline fn id() TypeId {
            return @enumFromInt(@intFromPtr(&name));
        }
    };
    return Tag.id();
}

fn typeIdInt(comptime T: type) usize {
    return @intFromEnum(typeId(T));
}
