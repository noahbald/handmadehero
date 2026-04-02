const std = @import("std");

const sdl3 = @import("sdl3");

const UserData = struct {
    running: bool = true,
    white: bool = true,
    window: sdl3.video.Window,
    bitmap_memory: sdl3.surface.Surface,

    const Self = @This();

    const pixels: [16]u8 align(32) = .{
        0xff, 0xff, 0x0,  0x0,
        0xff, 0x0,  0xff, 0x0,
        0xff, 0x0,  0x0,  0xff,
        0x88, 0xff, 0xff, 0xff,
    };

    pub fn init(window: sdl3.video.Window) !Self {
        const bitmap_memory: sdl3.surface.Surface = try .initFrom(
            2,
            2,
            sdl3.pixels.Format.array_abgr_32,
            &Self.pixels,
        );
        return .{
            .window = window,
            .bitmap_memory = bitmap_memory,
        };
    }

    pub fn deinit(self: Self) void {
        self.bitmap_memory.deinit();
    }

    pub fn paint(self: Self) !void {
        const surface = try self.window.getSurface();
        try self.update_window(surface);
        try self.window.updateSurface();
    }

    fn update_window(self: Self, surface: sdl3.surface.Surface) !void {
        try self.bitmap_memory.stretch(try self.bitmap_memory.getClipRect(), surface, try surface.getClipRect(), .linear);
    }
};

fn main_window_callback(user_data: ?*UserData, event: *sdl3.events.Event) bool {
    switch (event.*) {
        .window_resized, .window_moved => {
            if (user_data) |data| {
                data.paint() catch {
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

    var user_data: UserData = try .init(window);
    defer user_data.deinit();
    try user_data.paint();

    const filter = try sdl3.events.addWatch(UserData, &main_window_callback, &user_data);
    defer sdl3.events.removeWatch(filter, &user_data);

    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = 120 } };
    while (user_data.running) {
        _ = capper.delay();
        try user_data.paint();
        sdl3.events.pump();
    }
}
