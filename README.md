# Framework an opinionated minimal game/app engine/framework.
A simple runnable example can be found in `sandbox` and can be ran from the repo by using `zig build run`
Font rendering is still hella scuffed idk how to fix that
The main principle for this engine is everything is a resource. From basic stuff like the window, renderer, to time, fps. Primitives used across the codebase can be found in `src/primitive`. Thats what you will interact with most of the time.


## TODO:
[ ] Restructure renderbatch and views to support proper optimizations for each type of renderable, at the moment we use transient buffers which is only good for per-frame geometry like text
[ ] Fix memory leaks (im lazy, most of them are shutdown logic)
[ ] Improve camera system
[ ] Introduce more primitives and renderables
[ ] Static mesh rendering
[ ] Basic Physics
[ ] Materials, lighting, render passes
[ ] Introduce a better pipeline and more views, atm we only have @"2d" for 2d rendering and @"3d" for 3d rendering
