const std = @import("std");

const sdl3 = @import("sdl3");

pub fn messageBox() !void {
    try sdl3.message_box.showSimple(.{}, "Handmade Hero", "This is Handmade Hero.", null);
}
