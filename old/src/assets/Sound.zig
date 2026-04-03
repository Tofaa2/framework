/// Represents a sound asset used for audio playback.
/// Minimal wrapper around a file path for C interop with audio backends.
const Sound = @This();

/// The null-terminated file path to the audio file.
path: [:0]const u8, // null-terminated for C interop

pub fn init(path: [:0]const u8) Sound {
    return .{ .path = path };
}
