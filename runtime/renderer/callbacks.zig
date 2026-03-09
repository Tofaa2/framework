const std = @import("std");
const bgfx = @cImport({
    @cInclude("bgfx/c99/bgfx.h");
});

// We import vsnprintf from libc to handle the formatting safely
extern "c" fn vsnprintf(buf: [*c]u8, size: usize, format: [*c]const u8, args: *anyopaque) c_int;

pub const BgfxCallbacks = struct {

    // Update your traceVargs function signature to use the exact type expected by the vtable
    fn traceVargs(
        _this: ?*bgfx.bgfx_callback_interface_t,
        filePath: [*c]const u8,
        line: u16,
        format: [*c]const u8,
        argList: [*c]u8, // Changed from *anyopaque to [*c]u8 to match bgfx.h
    ) callconv(.c) void {
        _ = _this;

        var buffer: [2048]u8 = undefined;

        // Cast the argList back to the type vsnprintf expects (which is usually *anyopaque or va_list)
        // On most C implementations, passing the [*c]u8 directly works if it's the right internal size
        _ = vsnprintf(&buffer, buffer.len, format, @ptrCast(argList));

        const path = std.mem.span(filePath);
        const msg = std.mem.sliceTo(&buffer, 0);

        std.debug.print("[BGFX TRACE] {s}:{d} - {s}\n", .{ path, line, msg });
    }

    fn traceVargs0(_this: ?*bgfx.bgfx_callback_interface_t, filePath: [*c]const u8, line: u16, format: [*c]const u8, argList: *anyopaque) callconv(.c) void {
        _ = _this;

        var buffer: [2048]u8 = undefined;
        // Use libc vsnprintf to format the string into our buffer
        _ = vsnprintf(&buffer, buffer.len, format, argList);

        const path = std.mem.span(filePath);
        const msg = std.mem.sliceTo(&buffer, 0);

        std.debug.print("[BGFX TRACE] {s}:{d} - {s}\n", .{ path, line, msg });
    }

    fn fatal(_this: ?*bgfx.bgfx_callback_interface_t, filePath: [*c]const u8, line: u16, code: bgfx.bgfx_fatal_t, str: [*c]const u8) callconv(.c) void {
        _ = _this;
        _ = code;
        std.debug.print("\n[BGFX FATAL ERROR] {s}:{d} - {s}\n", .{ filePath, line, str });
        std.process.exit(1);
    }

    // --- Minimal required stubs ---
    fn profilerBegin(_this: ?*bgfx.bgfx_callback_interface_t, n: [*c]const u8, c: u32, f: [*c]const u8, l: u16) callconv(.c) void {
        _ = _this;
        _ = n;
        _ = c;
        _ = f;
        _ = l;
    }
    fn profilerBeginLiteral(_this: ?*bgfx.bgfx_callback_interface_t, n: [*c]const u8, c: u32, f: [*c]const u8, l: u16) callconv(.c) void {
        _ = _this;
        _ = n;
        _ = c;
        _ = f;
        _ = l;
    }
    fn profilerEnd(_this: ?*bgfx.bgfx_callback_interface_t) callconv(.c) void {
        _ = _this;
    }
    fn cacheReadSize(_this: ?*bgfx.bgfx_callback_interface_t, id: u64) callconv(.c) u32 {
        _ = _this;
        _ = id;
        return 0;
    }
    fn cacheRead(_this: ?*bgfx.bgfx_callback_interface_t, id: u64, d: ?*anyopaque, s: u32) callconv(.c) bool {
        _ = _this;
        _ = id;
        _ = d;
        _ = s;
        return false;
    }
    fn cacheWrite(_this: ?*bgfx.bgfx_callback_interface_t, id: u64, d: ?*const anyopaque, s: u32) callconv(.c) void {
        _ = _this;
        _ = id;
        _ = d;
        _ = s;
    }
    fn screenShot(_this: ?*bgfx.bgfx_callback_interface_t, f: [*c]const u8, w: u32, h: u32, p: u32, d: ?*const anyopaque, s: u32, y: bool) callconv(.c) void {
        _ = _this;
        _ = f;
        _ = w;
        _ = h;
        _ = p;
        _ = d;
        _ = s;
        _ = y;
    }
    fn captureBegin(_this: ?*bgfx.bgfx_callback_interface_t, w: u32, h: u32, p: u32, f: bgfx.bgfx_texture_format_t, y: bool) callconv(.c) void {
        _ = _this;
        _ = w;
        _ = h;
        _ = p;
        _ = f;
        _ = y;
    }
    fn captureEnd(_this: ?*bgfx.bgfx_callback_interface_t) callconv(.c) void {
        _ = _this;
    }
    fn captureFrame(_this: ?*bgfx.bgfx_callback_interface_t, d: ?*const anyopaque, s: u32) callconv(.c) void {
        _ = _this;
        _ = d;
        _ = s;
    }

    var vtbl = bgfx.bgfx_callback_vtbl_t{
        .fatal = fatal,
        .trace_vargs = traceVargs,
        .profiler_begin = profilerBegin,
        .profiler_begin_literal = profilerBeginLiteral,
        .profiler_end = profilerEnd,
        .cache_read_size = cacheReadSize,
        .cache_read = cacheRead,
        .cache_write = cacheWrite,
        .screen_shot = screenShot,
        .capture_begin = captureBegin,
        .capture_end = captureEnd,
        .capture_frame = captureFrame,
    };

    pub var interface = bgfx.bgfx_callback_interface_t{ .vtbl = &vtbl };
};
