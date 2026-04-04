const std = @import("std");

const sdl3 = @import("sdl3");

const COLOUR_WIDTH = 255;
const COLOUR_HEIGHT = 255;
const COLOUR_BYTES = 4;

const UserData = struct {
    running: bool = true,
    x_offset: i32 = 0,
    y_offset: i32 = 0,
    window: sdl3.video.Window,
    pixels: [COLOUR_WIDTH * COLOUR_HEIGHT * COLOUR_BYTES]u8 align(32) = undefined,

    const Self = @This();

    pub fn init(window: sdl3.video.Window) Self {
        var self: Self = .{ .window = window };
        for (0..COLOUR_HEIGHT) |y| {
            const row = COLOUR_WIDTH * y * COLOUR_BYTES;
            for (0..COLOUR_WIDTH) |x| {
                const ptr = row + (x * COLOUR_BYTES);
                const blue = @as(u32, @as(u8, @truncate(x)));
                const green = @as(u32, @as(u8, @truncate(y)));
                std.mem.writeInt(
                    u32,
                    self.pixels[ptr..][0..COLOUR_BYTES],
                    (green << 8) | blue,
                    .big,
                );
            }
        }
        return self;
    }

    pub fn paint(self: Self) !void {
        const surface = try self.window.getSurface();
        try self.render_weird_gradient(surface);
        try self.window.updateSurface();
    }

    fn render_weird_gradient(self: Self, surface: sdl3.surface.Surface) !void {
        const bitmap: sdl3.surface.Surface = try .initFrom(COLOUR_WIDTH, COLOUR_HEIGHT, sdl3.pixels.Format.array_xrgb_32, &self.pixels);

        defer bitmap.deinit();
        const bitmap_source = try bitmap.getClipRect();
        const surface_target = try surface.getClipRect();
        var target = surface_target;
        target.x = self.x_offset;
        target.y = self.y_offset;
        try bitmap.blitTiled(bitmap_source, surface, target);

        var source = bitmap_source;
        if (self.x_offset > 0 and self.y_offset > 0) {
            source.x = COLOUR_WIDTH - self.x_offset;
            source.y = COLOUR_HEIGHT - self.y_offset;
            try bitmap.blit(source, surface, null);
        }
        if (self.x_offset > 0) {
            source = bitmap_source;
            source.x = COLOUR_WIDTH - self.x_offset;
            target = surface_target;
            target.y = self.y_offset;
            target.w = self.x_offset;
            try bitmap.blitTiled(source, surface, target);
        }
        if (self.y_offset > 0) {
            source = bitmap_source;
            source.y = COLOUR_HEIGHT - self.y_offset;
            target = surface_target;
            target.x = self.x_offset;
            target.h = self.y_offset;
            try bitmap.blitTiled(source, surface, target);
        }
    }
};

fn main_window_callback(user_data: ?*UserData, event: *sdl3.events.Event) bool {
    switch (event.*) {
        .window_resized, .window_moved => {
            if (user_data) |data| {
                data.paint() catch {
                    return false;
                };
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

    var user_data: UserData = .init(window);
    try user_data.paint();

    const filter = try sdl3.events.addWatch(UserData, &main_window_callback, &user_data);
    defer sdl3.events.removeWatch(filter, &user_data);

    const fps = 120;
    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = fps } };
    while (user_data.running) {
        _ = capper.delay() * fps;
        user_data.x_offset = @mod(user_data.x_offset + 1, 0xff);
        user_data.y_offset = @mod(user_data.y_offset + 1, 0xff);
        try user_data.paint();
        sdl3.events.pump();
    }
}
