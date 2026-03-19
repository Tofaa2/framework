# Framework an opinionated minimal game/app engine/framework.

A simple runnable example can be found in `sandbox` and can be ran from the repo by using `zig build run`
Font rendering is still hella scuffed idk how to fix that
The main principle for this engine is everything is a resource. From basic stuff like the window, renderer, to time, fps. Primitives used across the codebase can be found in `src/primitive`. Thats what you will interact with most of the time.
Framework is extremely bare-bones, the design philosophy is maximum flexibility, I intend to keed it that way, stuff in unity might take a few buttons but a 100 lines of code in framework but my goal isnt minimizing the lines of code the end user writes. I intend on having a scene editor down the line to define prefabs, edit world geometry and whatever runs oninit, etc but thats a thought for down the line, I think even with this lowlevel approach once i have enough utilities and baked in features available there wont be a need for working directly with scenes besides prefab QOL.


## TODO:
- [x] Restructure renderbatch and views to support proper optimizations for each type of renderable, at the moment we use transient buffers which is only good for per-frame geometry like text
- [ ] Fix memory leaks (im lazy, most of them are shutdown logic)
- [x] Improve camera system
- [ ] Introduce more primitives and renderables
- [x] Static mesh rendering
- [ ] Basic Physics
- [ ] Materials, lighting, render passes
- [ ] Introduce a better pipeline and more views, atm we only have @"2d" for 2d rendering and @"3d" for 3d rendering
- [ ] Let user take cli arguments easily, allowing for cli args for renderer type etc.
- [ ] Prefab system for creating "default" entities
- [ ] Switch to our own in-house ecs
- [ ] Scene editor and a basic scripting API in a seperate module and executable.
- [ ] Backface culling and other optimizations
