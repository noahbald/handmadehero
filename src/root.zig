const std = @import("std");

const sdl3 = @import("sdl3");

const UserData = struct {
    running: bool = true,
    white: bool = true,
    window: sdl3.video.Window,
};

fn main_window_callback(user_data: ?*UserData, event: *sdl3.events.Event) bool {
    switch (event.*) {
        .window_resized, .window_moved => {
            if (user_data) |data| {
                render(data) catch {
                    return false;
                };
                data.*.white = !data.*.white;
            }
        },
        .quit, .terminating => {
            if (user_data) |data| {
                data.*.running = false;
            }
        },
        else => {},
    }
    return true;
}

pub fn win_main() !void {
    defer sdl3.shutdown();

    const init: sdl3.InitFlags = .{ .video = true };
    try sdl3.init(init);
    defer sdl3.quit(init);

    const window = try sdl3.video.Window.init("Handmade Hero", 720, 420, .{ .resizable = true });
    defer window.deinit();

    var user_data: UserData = .{ .window = window };
    try render(&user_data);

    const filter = try sdl3.events.addWatch(UserData, &main_window_callback, &user_data);
    defer sdl3.events.removeWatch(filter, &user_data);

    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = 120 } };
    while (user_data.running) {
        _ = capper.delay();
        sdl3.events.pump();
    }
}

fn render(user_data: *const UserData) !void {
    const surface = try user_data.window.getSurface();
    try surface.fillRect(null, .{ .value = if (user_data.white) 0xffffff else 0 });
    try user_data.window.updateSurface();
}
