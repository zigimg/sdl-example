const std = @import("std");
const SDL = @import("sdl2");
const zigimg = @import("zigimg");
const utils = @import("utils.zig");


/// # Usage
/// Specify the relative path to an image from the command line as an argument to this executable.
/// This image will be displayed.
/// # Example
/// `zig build run -- assets/logo.bmp`
pub fn main() anyerror!void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _=gpa.deinit();
    var allocator : *std.mem.Allocator = &gpa.allocator;

    try SDL.init(.{.video = true, .events = true, .audio = false});
    defer SDL.quit();

    var file = try utils.fileFromProcessArgs(allocator);

    const img = try zigimg.image.Image.fromFile(allocator,&file);
    defer img.deinit();

    var window = try SDL.createWindow("Example: zigimg with SDL2", .{.centered={}}, .{.centered={}}, img.width, img.height, .{.shown=true});
    defer window.destroy();
    
    var renderer = try SDL.createRenderer(window, null, .{});
    defer renderer.destroy();

    const dst_rect = SDL.Rectangle{.x=0, .y=0, .width = @intCast(c_int, img.width),  .height = @intCast(c_int, img.height)};

    var texture = try utils.sdlTextureFromImage(renderer, img);

    try renderer.setColor(SDL.Color{.r=128,.g=128,.b=128,.a=0});
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