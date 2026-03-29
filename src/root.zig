// ----- CORE -----

/// Entry point structure for framework.
/// Contains the main application loop and manages core components.
/// The name of the window that spawns will default to the App name.
/// Internally will initialize a 6mb temporary stack allocator
/// for use in the loop, It should be used for per-frame allocations
/// Will also internally initialize the renderer, and bind physics, rendering and audio systems.
/// The debug flag is set true if the build is not a release mode and is a compile time set constant.
/// Variables inside this struct are owned by the app and should NEVER be mutated directly, only accessed, Except for App#running.
pub const App = @import("core/App.zig");

/// Manages window creation, event processing, and input state.
pub const Window = @import("core/Window.zig");

/// Manages loading, caching, and reference counting of game assets.
pub const AssetPool = @import("core/AssetPool.zig");

/// Manages singleton resources and global game states.
pub const ResourcePool = @import("core/ResourcePool.zig");

/// Manages application time, delta timing, and FPS calculation.
pub const Time = @import("core/Time.zig");

/// Manages high-level keyboard input mapping and callbacks.
pub const Keybinds = @import("core/Keybinds.zig");

/// Type-safe handle to an asset managed by the AssetPool.
pub const Handle = AssetPool.Handle;

/// Manages audio playback and resource caching using miniaudio.
pub const SoundManager = @import("core/SoundManager.zig");

/// Manages the entity component system (ECS) and system scheduling.
pub const World = @import("core/World.zig");

/// Tagged union representing all possible application-level events.
pub const Event = @import("core/event.zig").Event;

/// TODO:
pub const GenericEventManager = @import("core/event.zig").GenericEventManager;

/// Default event manager instance.
pub const EventManager = @import("core/event.zig").EventManager;

/// Interface for extending the application with custom systems.
pub const Plugin = @import("core/Plugin.zig").Plugin;

// ----- ASSETS -----

/// Simple color gradient skybox
pub const Skybox = @import("assets/Skybox.zig");

/// Defines global ambient lighting properties for the scene.
pub const AmbientLight = @import("assets/AmbientLight.zig");

/// Represents a font asset ready for rendering.
pub const Font = @import("assets/Font.zig");

/// Represents a textured image asset for use in rendering.
pub const Image = @import("assets/Image.zig");

/// Represents a sound asset used for audio playback.
pub const Sound = @import("assets/Sound.zig");

/// Defines how a surface should be rendered.
pub const Material = @import("assets/Material.zig");

/// Defines a cubemap. Which is a texture that is 6 baked textures.
pub const Cubemap = @import("assets/Cubemap.zig");

/// TODO:

// ----- COMPONENTS -----

/// Defines a reference point for positioning UI elements.
pub const Anchor = @import("components/Anchor.zig");

/// Component for a 2D camera in world space.
pub const Camera2D = @import("components/Camera2D.zig");

/// Component for a 3D camera in world space.
pub const Camera3D = @import("components/Camera3D.zig");

/// Represents an RGBA8 color component.
pub const Color = @import("components/Color.zig");

/// Defines a light source component for 3D scenes.
pub const Light = @import("components/Light.zig");

/// Union representing different types of primitives that can be rendered.
pub const Renderable = @import("components/renderable.zig").Renderable;

/// Defines spatial transformation for entities.
pub const Transform = @import("components/Transform.zig");

/// sound source component for audio playback from an entity.
pub const SoundSource = @import("components/SoundSource.zig");

/// Defines per-entity gravity acceleration.
pub const Gravity = @import("components/Gravity.zig");

/// Defines a dynamic physics body component.
pub const RigidBody = @import("components/RigidBody.zig");

/// Axis-aligned bounding box collider for physics detection.
pub const Collider = @import("components/Collider.zig");

/// Defines linear velocity in world space.
pub const Velocity = @import("components/Velocity.zig");

// ----- RENDERER -----

/// TODO:
pub const ShaderProgram = @import("renderer/ShaderProgram.zig");

/// TODO:
pub const Viewport = @import("renderer/Viewport.zig");

/// TODO:
pub const View = @import("renderer/View.zig");

/// TODO:
pub const Vertex = @import("renderer/Vertex.zig");

/// TODO:
pub const ObjLoader = @import("renderer/ObjLoader.zig");

/// TODO:
pub const Renderer = @import("renderer/root.zig").Renderer;

/// TODO:
pub const MeshBuilder = @import("renderer/MeshBuilder.zig");

/// TODO:
pub const Mesh = @import("renderer/Mesh.zig");

/// TODO:
pub const DynamicMesh = @import("renderer/DynamicMesh.zig");

/// TODO:
pub const rmath = @import("renderer/math.zig");

// ----- ECS -----

/// TODO:
pub const ecs = @import("ecs");
pub const ecs2 = @import("slime");

/// TODO:
pub const Entity = ecs.Entity;
// pub const World = ecs.Registry;

// ----- UTILS -----

/// TODO:
pub const utils = @import("utils/root.zig");

/// TODO:
pub const thirdparty = @import("thirdparty");

// ----- SYSTEMS -----

/// TODO:
pub const RenderSystem = @import("systems/RenderSystem.zig");

/// TODO:
pub const AudioSystem = @import("systems/AudioSystem.zig");

/// TODO:
pub const PhysicsSystem = @import("systems/PhysicsSystem.zig");

comptime {
    @import("std").testing.refAllDeclsRecursive(@This());
}
