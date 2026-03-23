const std = @import("std");
const c = @import("thirdparty").miniaudio;
const SoundManager = @This();
const Sound = @import("../assets/Sound.zig");
const MAX_INSTANCES = 8;

const SoundInstance = struct {
    sound: c.ma_sound,
    active: bool,
};

const SoundPool = struct {
    // Decoded audio data shared across all instances
    buffer: c.ma_audio_buffer,
    buffer_ready: bool,
    instances: [MAX_INSTANCES]SoundInstance,

    pub fn init() SoundPool {
        return .{
            .buffer = std.mem.zeroes(c.ma_audio_buffer),
            .buffer_ready = false,
            .instances = [_]SoundInstance{.{
                .sound = std.mem.zeroes(c.ma_sound),
                .active = false,
            }} ** MAX_INSTANCES,
        };
    }

    pub fn deinit(self: *SoundPool) void {
        for (&self.instances) |*inst| {
            if (inst.active) {
                c.ma_sound_uninit(&inst.sound);
                inst.active = false;
            }
        }
        if (self.buffer_ready) {
            c.ma_audio_buffer_uninit(&self.buffer);
            self.buffer_ready = false;
        }
    }

    pub fn getFreeSlot(self: *SoundPool) usize {
        for (&self.instances, 0..) |*inst, i| {
            if (!inst.active) return i;
            if (c.ma_sound_at_end(&inst.sound) == c.MA_TRUE) {
                c.ma_sound_uninit(&inst.sound);
                inst.active = false;
                return i;
            }
        }
        c.ma_sound_uninit(&self.instances[0].sound);
        self.instances[0].active = false;
        return 0;
    }
};

allocator: std.mem.Allocator,
engine: c.ma_engine,
engine_ready: bool,
cache: std.StringHashMap(SoundPool),

pub fn init(allocator: std.mem.Allocator) !*SoundManager {
    const manager = try allocator.create(SoundManager);
    errdefer allocator.destroy(manager);

    manager.* = .{
        .allocator = allocator,
        .engine = std.mem.zeroes(c.ma_engine),
        .engine_ready = false,
        .cache = std.StringHashMap(SoundPool).init(allocator),
    };

    const result = c.ma_engine_init(null, &manager.engine);
    if (result != c.MA_SUCCESS) {
        allocator.destroy(manager);
        std.log.err("ma_engine_init failed: {d}", .{result});
        return error.EngineInitFailed;
    }
    manager.engine_ready = true;

    return manager;
}

pub fn deinit(self: *SoundManager) void {
    var it = self.cache.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit();
        self.allocator.free(entry.key_ptr.*);
    }
    self.cache.deinit();

    if (self.engine_ready) {
        c.ma_engine_uninit(&self.engine);
    }
    self.allocator.destroy(self);
}

pub fn update(self: *SoundManager) void {
    var it = self.cache.iterator();
    while (it.next()) |entry| {
        for (&entry.value_ptr.instances) |*inst| {
            if (inst.active and c.ma_sound_at_end(&inst.sound) == c.MA_TRUE) {
                c.ma_sound_uninit(&inst.sound);
                inst.active = false;
            }
        }
    }
}

// Pause/resume all sounds
pub fn setPaused(self: *SoundManager, paused: bool) void {
    if (paused) {
        _ = c.ma_engine_stop(&self.engine);
    } else {
        _ = c.ma_engine_start(&self.engine);
    }
}

// Master volume, 0.0 - 1.0
pub fn setMasterVolume(self: *SoundManager, volume: f32) void {
    c.ma_engine_set_volume(&self.engine, volume);
}

fn getOrCreatePool(self: *SoundManager, path: []const u8) !*SoundPool {
    if (self.cache.getPtr(path)) |pool| return pool;

    const key = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(key);

    try self.cache.put(key, SoundPool.init());
    return self.cache.getPtr(path).?;
}
pub fn play(self: *SoundManager, sound: *const Sound, volume: f32, pitch: f32) !u32 {
    const pool = try self.getOrCreatePool(sound.path);
    const slot = pool.getFreeSlot();
    const inst = &pool.instances[slot];
    const flags = c.MA_SOUND_FLAG_DECODE;
    const result = c.ma_sound_init_from_file(
        &self.engine,
        sound.path.ptr,
        flags,
        null,
        null,
        &inst.sound,
    );
    if (result != c.MA_SUCCESS) {
        return error.SoundLoadFailed;
    }

    inst.active = true;
    c.ma_sound_set_volume(&inst.sound, volume);
    c.ma_sound_set_pitch(&inst.sound, pitch);

    const start_result = c.ma_sound_start(&inst.sound);
    if (start_result != c.MA_SUCCESS) return error.SoundStartFailed;

    const pool_idx = self.getPoolIndex(sound.path);
    const handle = (@as(u32, @intCast(pool_idx)) << 16) | @as(u32, @intCast(slot));
    return handle;
}

// Returns whether a previously returned handle is still playing
pub fn isPlaying(self: *SoundManager, handle: u32) bool {
    const pool_idx = handle >> 16;
    const slot_idx = handle & 0xFFFF;

    const pool = self.getPoolByIndex(pool_idx) orelse return false;
    const inst = &pool.instances[slot_idx];
    if (!inst.active) return false;
    return c.ma_sound_at_end(&inst.sound) == c.MA_FALSE;
}

pub fn setVolume(self: *SoundManager, handle: u32, volume: f32) void {
    const inst = self.getInstance(handle) orelse return;
    c.ma_sound_set_volume(&inst.sound, volume);
}

pub fn setPitch(self: *SoundManager, handle: u32, pitch: f32) void {
    const inst = self.getInstance(handle) orelse return;
    c.ma_sound_set_pitch(&inst.sound, pitch);
}

pub fn stop(self: *SoundManager, handle: u32) void {
    const inst = self.getInstance(handle) orelse return;
    _ = c.ma_sound_stop(&inst.sound);
}

// Internal helpers
fn getPoolIndex(self: *SoundManager, path: []const u8) u16 {
    var i: u16 = 0;
    var it = self.cache.iterator();
    while (it.next()) |entry| : (i += 1) {
        if (std.mem.eql(u8, entry.key_ptr.*, path)) return i;
    }
    unreachable; // pool must exist before calling this
}

fn getPoolByIndex(self: *SoundManager, idx: u32) ?*SoundPool {
    var i: u32 = 0;
    var it = self.cache.iterator();
    while (it.next()) |entry| : (i += 1) {
        if (i == idx) return entry.value_ptr;
    }
    return null;
}

fn getInstance(self: *SoundManager, handle: u32) ?*SoundInstance {
    const pool = self.getPoolByIndex(handle >> 16) orelse return null;
    const slot = handle & 0xFFFF;
    if (slot >= MAX_INSTANCES) return null;
    const inst = &pool.instances[slot];
    if (!inst.active) return null;
    return inst;
}
