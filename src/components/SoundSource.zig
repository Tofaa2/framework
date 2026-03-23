// SoundSource.zig
const SoundSource = @This();
const root = @import("../root.zig");
const std = @import("std");

pub const INVALID_HANDLE: u32 = std.math.maxInt(u32);

sound: root.Handle(root.Sound) = .invalid,
distance: f32 = 0.0,
volume: f32 = 1.0,
pitch: f32 = 1.0,
looping: bool = false,
internal_handle: u32 = INVALID_HANDLE, // replaces internal_idx, now a packed pool+slot
