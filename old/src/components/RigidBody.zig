/// Defines a dynamic physics body component. 
/// Add to any entity you want simulated by the physics system.
/// Works in both 2D (set Z components to 0) and 3D.
pub const RigidBody = @This();

/// If true, this body does not move but still participates in collision detection.
is_static: bool = false,
/// The mass of the body in world units.
mass: f32 = 1.0,
/// Bounciness coefficient. 0.0 is inelastic, 1.0 is fully elastic.
restitution: f32 = 0.0,
/// Linear drag coefficient applied per frame (0.0 = no drag, 1.0 = instant stop).
drag: f32 = 0.0,
