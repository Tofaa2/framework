const std = @import("std");


pub const Io = struct {
    allocator: std.mem.Allocator,

    pub fn readFile(self: Io, path: []const u8) ![]u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        return try file.readToEndAlloc(self.allocator, 4096);
    }

    pub fn readFileMod(self: Io, path: []const u8, modifier: fn (data: []u8) void) !void {
        const data = try self.readFile(path);
        defer self.allocator.free(data);
        modifier(data);
    }

    pub fn readJson(self: Io, data: []const u8, comptime T: type) !std.json.Parsed(T) {
        return std.json.parseFromSlice(T, self.allocator, data, .{});
    }

};
