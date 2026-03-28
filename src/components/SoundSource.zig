/// Defines a sound source component for audio playback from an entity.
const SoundSource = @This();
const root = @import("../root.zig");
const std = @import("std");

/// A constant representing an invalid sound handle.
pub const INVALID_HANDLE: u32 = std.math.maxInt(u32);

/// The current sound handle allocated from the AssetPool.
sound: root.Handle(root.Sound) = .invalid,
/// Distance-based volume attenuation.
distance: f32 = 0.0,
/// The current playback volume, from 0.0 to 1.0.
volume: f32 = 1.0,
/// The current playback pitch, from 0.0 to 1.0.
pitch: f32 = 1.0,
/// Whether the sound should automatically repeat on completion.
looping: bool = false,
/// Internal handle mapped by the SoundManager for this source.
internal_handle: u32 = INVALID_HANDLE, // replaces internal_idx, now a packed pool+slot
