# framework
A minimal game engine implementation that wraps around raylib in Zig

# How To Use
1. Clone this repo, put it somewhere in your project. (ex: external/framework)
2. In your projects build.zig.zon file. Add the following dependency
```
        .@"framework" = .{
            .path = "framework path in your projects folder."
        },
```
3. Head over to your build.zig file and add the following lines of code.
```
    const framework_dep = b.dependency("framework", .{
        .target = target,
        .optimize = optimize
    });
    const framework_artifact = framework_dep.artifact("framework");
    const framework = framework_dep.module("framework");

    // Then link it all 
    exe.linkLibrary(framework_artifact);
    exe.root_module.addImport("framework", framework);
```
4. Build project to see if it works.

