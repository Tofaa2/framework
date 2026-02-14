# framework-scheduler

A very opinionated scheduler api. This is not a thread pool or a task queue. Its current purpose is to provide a simple stage based system
for managing tasks in a sequential manner split across multiple phases.


## Example
```zig
const MyCtx = struct {
    name: []const u8,
};

const MyPhases = enum {
    init,
    update,
    deinit,
};


const Scheduler = @import("framework-scheduler").Scheduler(MyCtx, MyPhases);

pub fn main() !void {
    const allocator = ...;
    const scheduler = Scheduler.init(.{
        .allocator = allocator,
    });
    defer scheduler.deinit();
    const my_ctx = MyCtx{
        .name = "My Context",
    };
    
    scheduler.run(&my_ctx, .init);
    while (true) {
        scheduler.run(&my_ctx, .update);
    }
    scheduler.run(&my_ctx, .deinit);
}

```
