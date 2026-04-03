const std = @import("std");

const sdl3 = @import("sdl3");

const UserData = struct {
    running: bool = true,
    white: bool = true,
    x_offset: usize = 0,
    y_offset: usize = 0,
    window: sdl3.video.Window,

    const Self = @This();

    pub fn paint(self: Self) !void {
        const surface = try self.window.getSurface();
        try self.render_weird_gradient(surface);
        try self.window.updateSurface();
    }

    fn render_weird_gradient(self: Self, surface: sdl3.surface.Surface) !void {
        const width = 255;
        const height = 255;
        const bytes_per_pixel = 4;
        const alignment = 8 * bytes_per_pixel;
        var pixels: [width * height * bytes_per_pixel]u8 align(alignment) = undefined;
        for (0..height) |y| {
            const row = width * y * bytes_per_pixel;
            for (0..width) |x| {
                const ptr = row + (x * bytes_per_pixel);
                const blue = @as(u32, @as(u8, @truncate(x +% self.x_offset)));
                const green = @as(u32, @as(u8, @truncate(y +% self.y_offset)));
                std.mem.writeInt(
                    u32,
                    pixels[ptr..][0..bytes_per_pixel],
                    (green << 8) | blue,
                    .big,
                );
            }
        }

        const bitmap: sdl3.surface.Surface = try .initFrom(width, height, sdl3.pixels.Format.array_xrgb_32, &pixels);
        defer bitmap.deinit();
        try bitmap.blitTiled(try bitmap.getClipRect(), surface, null);
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

    var user_data: UserData = .{ .window = window };
    try user_data.paint();

    const filter = try sdl3.events.addWatch(UserData, &main_window_callback, &user_data);
    defer sdl3.events.removeWatch(filter, &user_data);

    const fps = 120;
    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = fps } };
    while (user_data.running) {
        _ = capper.delay() * fps;
        user_data.x_offset = user_data.x_offset -% 1;
        try user_data.paint();
        sdl3.events.pump();
    }
}
