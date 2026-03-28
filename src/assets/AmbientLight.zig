/// Defines the global ambient lighting properties for the scene.
/// This affects all objects in the scene regardless of their position or direct light sources.
const Color = @import("../components/Color.zig");
const AmbientLight = @This();

/// The color and intensity of the ambient light.
/// RGBA values where components represent light contribution.
color: Color = .{ .r = 50, .g = 50, .b = 50, .a = 255 },
