const rl = @import("raylib");
const std = @import("std");

pub const FontRenderer = struct { 
    font: rl.Font,
    size: i32,
    spacing: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !FontRenderer {
        return .{
            .size = 20,
            .spacing = 2,
            .font = rl.getFontDefault(),
            .allocator = allocator
        };
    }

    pub fn renderTextColored(
        self: FontRenderer,
        text: [*:0]const u8,
        posX: i32, posY: i32,
        color: rl.Color
    ) void {
        rl.drawTextEx(self.font, text,
         .{.x = @floatFromInt(posX), .y = @floatFromInt(posY)},
          @floatFromInt(self.size), @floatFromInt(self.spacing), color);
    }

    pub fn renderTextColoredFormatted(
        self: FontRenderer,
        comptime text: []const u8,
        posX: i32, posY: i32,
        color: rl.Color,
        args: anytype
    ) !void {
        const formatted = try std.fmt.allocPrintZ(self.allocator, text, args);
        self.renderTextColored(formatted, posX, posY, color);
        self.allocator.free(formatted);
    }

    pub fn renderText(self: FontRenderer, text: [*:0]const u8, posX: i32, posY: i32) void {
        self.renderTextColored(text, posX, posY, rl.Color.white);
    }

    pub fn renderTextFormatted(self: FontRenderer, text: [*:0]const u8, posX: i32, posY: i32, args: anytype) !void {
      self.renderTextColoredFormatted(text, posX, posY, rl.Color.white, args);
    }

};
