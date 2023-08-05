const std = @import("std");
const SDL = @import("sdl2");
const zigimg = @import("zigimg");
const utils = @import("utils.zig");

/// # Usage
/// Specify the relative path to an image from the command line as an argument to this executable.
/// This image will be displayed.
/// # Example
/// This will open the given bmp image and display it. If we use the example like this we can open
/// 24 bit RGB and 32bit RGBA datasets.
/// `zig build run -- assets/logo.bmp`
/// We can also let the user specify how the conversion from a zigimg Image structure to a texture
/// will be performed. If nothing is specified, the buffers will be used as the pixels of an sdl surface.
/// But we can also optionally specify `--color-iter` as the first argument, which will tell the example program
/// to use the color iterator of the image to perform the conversion. This is even more flexible than the
/// buffer based algorithm, because it can deal with any kind of image data, not just 24/32 bit RGB(A).
pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator: std.mem.Allocator = gpa.allocator();

    try SDL.init(.{ .video = true, .events = true, .audio = false });
    defer SDL.quit();

    var program_config = try utils.parseProcessArgs(allocator);

    var img = try zigimg.Image.fromFile(allocator, &program_config.image_file);
    defer img.deinit();

    var window = try SDL.createWindow("Example: zigimg with SDL2", .{ .centered = {} }, .{ .centered = {} }, img.width, img.height, .{ .vis = .shown });
    defer window.destroy();

    var renderer = try SDL.createRenderer(window, null, .{});
    defer renderer.destroy();

    const dst_rect = SDL.Rectangle{ .x = 0, .y = 0, .width = @intCast(img.width), .height = @intCast(img.height) };

    // allow user to decide wheter the color iterator or should be used for conversion of if the image buffer should be
    // directly copied into a surface and then into a texture.
    var texture = switch (program_config.image_conversion) {
        .buffer => try utils.sdlTextureFromImage(renderer, img),
        .color_iterator => try utils.sdlTextureFromImageUsingColorIterator(renderer, img),
    };

    try renderer.setColor(SDL.Color{ .r = 128, .g = 128, .b = 128, .a = 0 });
    try renderer.clear();
    try renderer.copy(texture, null, dst_rect);
    renderer.present();

    mainloop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainloop,
                else => {},
            }
        }
    }
}
