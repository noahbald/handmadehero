const std = @import("std");

const sdl3 = @import("sdl3");

const COLOUR_WIDTH = 255;
const COLOUR_HEIGHT = 255;
const COLOUR_BYTES = 4;

const UserData = struct {
    running: bool = true,
    x_velocity: i16 = 0,
    y_velocity: i16 = 0,
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
        .key_down => |*e| {
            if (user_data) |data| {
                if (e.key) |key| {
                    switch (key) {
                        .up => data.y_velocity = -0xfff,
                        .right => data.x_velocity = 0xfff,
                        .down => data.y_velocity = 0xfff,
                        .left => data.x_velocity = -0xfff,
                        else => {},
                    }
                }
            }
        },
        .key_up => |*e| {
            if (user_data) |data| {
                if (e.key) |key| {
                    switch (key) {
                        .right, .left => data.x_velocity = 0,
                        .up, .down => data.y_velocity = 0,
                        else => {},
                    }
                }
            }
        },
        .gamepad_button_down => |*e| {
            switch (e.button) {
                .dpad_up, .dpad_down, .dpad_left, .dpad_right, .start, .back, .left_shoulder, .right_shoulder, .south, .east, .west, .north => {},
                else => {
                    if (user_data) |data| {
                        data.y_velocity = 0xff;
                    }
                },
            }
        },
        .gamepad_axis_motion => |*e| {
            switch (e.axis) {
                .left_x => if (user_data) |data| {
                    if (@abs(e.value) > 0xff) {
                        data.x_velocity = e.value;
                    } else {
                        data.x_velocity = 0;
                    }
                },
                .left_y => if (user_data) |data| {
                    if (@abs(e.value) > 0xff) {
                        data.y_velocity = e.value;
                    } else {
                        data.y_velocity = 0;
                    }
                },
                else => {},
            }
        },
        else => {},
    }
    return true;
}

fn main_playback_stream_callback(
    user_data: ?*UserData,
    stream: sdl3.audio.Stream,
    additional_amount: usize,
    total_amount: usize,
) void {
    _ = user_data;
    _ = total_amount;

    const data = std.heap.page_allocator.alloc(u8, additional_amount) catch return;
    defer std.heap.page_allocator.free(data);

    @memset(data, 0x80);
    stream.putData(data) catch return;
}

pub fn win_main() !void {
    defer sdl3.shutdown();

    _ = try sdl3.hints.set(.joystick_hidapi, "0");

    const init: sdl3.InitFlags = .{ .video = true, .gamepad = true, .joystick = true, .audio = true };
    try sdl3.init(init);
    defer sdl3.quit(init);
    const ids = try sdl3.gamepad.getGamepads();
    defer sdl3.free(ids);
    for (ids) |id| {
        _ = try sdl3.gamepad.Gamepad.init(id);
    }
    const playback_devices = try sdl3.audio.getPlaybackDevices();
    defer sdl3.free(playback_devices);
    const playback: sdl3.audio.Device = .{ .value = sdl3.c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK };

    const window = try sdl3.video.Window.init("Handmade Hero", 720, 420, .{ .resizable = true });
    defer window.deinit();

    var user_data: UserData = .init(window);
    try user_data.paint();

    const filter = try sdl3.events.addWatch(UserData, &main_window_callback, &user_data);
    defer sdl3.events.removeWatch(filter, &user_data);
    const stream = try playback.openStream(
        .{ .format = sdl3.audio.Format.unsigned_8_bit, .num_channels = 2, .sample_rate = 48_000 },
        UserData,
        main_playback_stream_callback,
        &user_data,
    );
    try stream.resumeDevice();
    defer stream.deinit();

    const fps = 120;
    var capper: sdl3.extras.FramerateCapper(f32) = .{ .mode = .{ .limited = fps } };
    while (user_data.running) {
        _ = capper.delay() * fps;
        user_data.x_offset = @mod(user_data.x_offset + @divFloor(user_data.x_velocity, 0xfff), 0xff);
        user_data.y_offset = @mod(user_data.y_offset + @divFloor(user_data.y_velocity, 0xfff), 0xff);
        try user_data.paint();
        sdl3.events.pump();
    }
}
