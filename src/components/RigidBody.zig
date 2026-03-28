/// A dynamic physics body. Add to any entity you want physics to affect.
/// Works in both 2D (set Z components to 0) and 3D.
velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
/// If true, this body does not move but still participates in collision detection.
is_static: bool = false,
mass: f32 = 1.0,
/// Bounciness coefficient. 0 = inelastic, 1 = fully elastic.
restitution: f32 = 0.0,
/// Linear drag coefficient applied per frame (0 = no drag, 1 = instant stop).
drag: f32 = 0.0,
