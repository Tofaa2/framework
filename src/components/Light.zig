/// Defines a light source component for 3D scenes.
const Color = @import("Color.zig");
const Light = @This();

/// The RGBA color of the light.
color: Color = .white,
/// The intensity or brightness of the light.
intensity: f32 = 1.0,
