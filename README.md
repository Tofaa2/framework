# framework
A minimal collection of libraries and tools for building general-purpose applications in zig.
Framework also comes with an app-sdk which is my flavored implementation of a minimal game engine.


## Installation
* Open the terminal
* Run the following command to install the library `zig fetch --save git+https://github.com/Tofaa2/framework`
* Go to your build.zig file and add any of the modules you need:
```zig
pub fn build(b: *std.Build) !void {
    const exe = ...;
    const framework_dep = b.dependency("framework");
    const scheduler_mod = framework_dep.module("framework-scheduler");
    exe.root_module.addImport("framework-scheduler", scheduler_mod); 
} 
```

To find a module you are interested in, look in the `src` directory. Each folder is its own module and a README.md file 
and their module name is "framework-<module_name>".

