const std = @import("std");
const root = @import("../root.zig");

pub const AudioPlugin = root.Plugin.init(plugin_build);

fn plugin_build(app: *root.App) void {
    app.world.scheduler.add(&.{root.SoundSource}, updateSounds);
    // app.world.scheduler.buildSystem(updateSounds)
    //     .writes(root.SoundSource)
    //     .inPhase(.update)
    //     .append();
}

fn updateSounds(world: *root.World) !void {
    const app: *root.App = @ptrCast(@alignCast(world.ctx.?));

    app.sounds.update();

    var iter = world.basicView(root.SoundSource);

    while (iter.next()) |ss_t| {
        const ss = world.get(root.SoundSource, ss_t.entity);
        if (!ss.sound.isValid()) continue;

        if (ss.internal_handle == root.SoundSource.INVALID_HANDLE) {
            const sound = app.assets.getAsset(root.Sound, ss.sound);
            if (sound) |s| {
                ss.internal_handle = app.sounds.play(s, ss.volume, ss.pitch) catch |err| {
                    std.log.err("Failed to play sound: {}", .{err});
                    continue;
                };
            }
        } else {
            app.sounds.setVolume(ss.internal_handle, ss.volume);
            app.sounds.setPitch(ss.internal_handle, ss.pitch);

            if (!app.sounds.isPlaying(ss.internal_handle)) {
                if (ss.looping) {
                    ss.internal_handle = root.SoundSource.INVALID_HANDLE;
                } else {
                    ss.sound = root.Handle(root.Sound).invalid;
                    ss.internal_handle = root.SoundSource.INVALID_HANDLE;
                }
            }
        }
    }
}
