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
pub const Window = @import("core/Window.zig");
pub const AssetPool = @import("core/AssetPool.zig");
pub const ResourcePool = @import("core/ResourcePool.zig");
pub const Time = @import("core/Time.zig");
pub const Keybinds = @import("core/Keybinds.zig");
pub const Handle = AssetPool.Handle;
pub const SoundManager = @import("core/SoundManager.zig");
pub const World = @import("core/World.zig");
pub const Event = @import("core/event.zig").Event;
pub const GenericEventManager = @import("core/event.zig").GenericEventManager;
pub const EventManager = @import("core/event.zig").EventManager;
pub const Plugin = @import("core/Plugin.zig").Plugin;

// ----- ASSETS -----
pub const AmbientLight = @import("assets/AmbientLight.zig");
pub const Font = @import("assets/Font.zig");
pub const Image = @import("assets/Image.zig");
pub const Sound = @import("assets/Sound.zig");
pub const Material = @import("assets/Material.zig");

// ----- COMPONENTS -----
pub const Anchor = @import("components/Anchor.zig");
pub const Camera2D = @import("components/Camera2D.zig");
pub const Camera3D = @import("components/Camera3D.zig");
pub const Color = @import("components/Color.zig");
pub const Light = @import("components/Light.zig");
pub const Renderable = @import("components/renderable.zig").Renderable;
pub const Transform = @import("components/Transform.zig");
pub const SoundSource = @import("components/SoundSource.zig");
pub const Gravity = @import("components/Gravity.zig");
pub const RigidBody = @import("components/RigidBody.zig");
pub const Collider = @import("components/Collider.zig");
pub const Velocity = @import("components/Velocity.zig");

// ----- RENDERER -----
pub const ShaderProgram = @import("renderer/ShaderProgram.zig");
pub const Viewport = @import("renderer/Viewport.zig");
pub const View = @import("renderer/View.zig");
pub const Vertex = @import("renderer/Vertex.zig");
pub const ObjLoader = @import("renderer/ObjLoader.zig");
pub const Renderer = @import("renderer/root.zig").Renderer;
pub const MeshBuilder = @import("renderer/MeshBuilder.zig");
pub const Mesh = @import("renderer/Mesh.zig");
pub const DynamicMesh = @import("renderer/DynamicMesh.zig");
pub const rmath = @import("renderer/math.zig");

// ----- ECS -----
pub const ecs = @import("ecs");
pub const Entity = ecs.Entity;
// pub const World = ecs.Registry;

// ----- UTILS -----
pub const utils = @import("utils/root.zig");

pub const thirdparty = @import("thirdparty");

// ----- SYSTEMS -----
pub const RenderSystem = @import("systems/RenderSystem.zig");
pub const AudioSystem = @import("systems/AudioSystem.zig");
pub const PhysicsSystem = @import("systems/PhysicsSystem.zig");

comptime {
    @import("std").testing.refAllDeclsRecursive(@This());
}
