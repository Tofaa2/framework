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

/// TODO:
pub const Window = @import("core/Window.zig");

/// TODO:
pub const AssetPool = @import("core/AssetPool.zig");

/// TODO:
pub const ResourcePool = @import("core/ResourcePool.zig");

/// TODO:
pub const Time = @import("core/Time.zig");

/// TODO:
pub const Keybinds = @import("core/Keybinds.zig");

/// TODO:
pub const Handle = AssetPool.Handle;

/// TODO:
pub const SoundManager = @import("core/SoundManager.zig");

/// TODO:
pub const World = @import("core/World.zig");

/// TODO:
pub const Event = @import("core/event.zig").Event;

/// TODO:
pub const GenericEventManager = @import("core/event.zig").GenericEventManager;

/// TODO:
pub const EventManager = @import("core/event.zig").EventManager;

/// TODO:
pub const Plugin = @import("core/Plugin.zig").Plugin;

// ----- ASSETS -----

/// TODO:
pub const AmbientLight = @import("assets/AmbientLight.zig");

/// TODO:
pub const Font = @import("assets/Font.zig");

/// TODO:
pub const Image = @import("assets/Image.zig");

/// TODO:
pub const Sound = @import("assets/Sound.zig");

/// TODO:
pub const Material = @import("assets/Material.zig");

/// TODO:

// ----- COMPONENTS -----

/// TODO:
pub const Anchor = @import("components/Anchor.zig");

/// TODO:
pub const Camera2D = @import("components/Camera2D.zig");

/// TODO:
pub const Camera3D = @import("components/Camera3D.zig");

/// TODO:
pub const Color = @import("components/Color.zig");

/// TODO:
pub const Light = @import("components/Light.zig");

/// TODO:
pub const Renderable = @import("components/renderable.zig").Renderable;

/// TODO:
pub const Transform = @import("components/Transform.zig");

/// TODO:
pub const SoundSource = @import("components/SoundSource.zig");

/// TODO:
pub const Gravity = @import("components/Gravity.zig");

/// TODO:
pub const RigidBody = @import("components/RigidBody.zig");

/// TODO:
pub const Collider = @import("components/Collider.zig");

/// TODO:
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
