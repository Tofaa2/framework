# Slime ECS

An experiment on ECS built in 3 days. Made for learning purposes and primarily for my game engine https://github.com/Tofaa2/framework
As framework was missing an in house entity component system that had prefabs and parallel scheduling and atomic getMut for components.
Slime is still very barebones and experimental, Ill be patching it up if i find stuff related to my engine

## Slime Prefabs
Prefabs for slime are essentially an id, mask and a set of components. There is a binary format for performance and a human readable/editable approach using json.

## Performance
Take these numbers with a grain of salt just like any performance tests. But for those of you who like numbers i guess here we go.
Tested on an i7 12700f.

```
benchmark                         n      total_ms    ns/entity
----------------------------------------------------------------
spawn P+V                      1000000     67.586 ms             67 ns/op
query iterate P+V              1000000      0.371 ms              0 ns/op
chunked + columnSlice P        1000000      0.595 ms              0 ns/op
getMut via query P             1000000      3.722 ms              3 ns/op
spawnPrefab (same prefab)      1000000     65.897 ms             65 ns/op
addComponent V (migrate)       1000000     80.321 ms             80 ns/op
removeComponent V (migrate)    1000000     75.255 ms             75 ns/op
despawn                        1000000      8.620 ms              8 ns/op
```
