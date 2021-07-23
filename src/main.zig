const std = @import("std");
const c = @import("sdl2");
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


    _= c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var file = try utils.fileFromProcessArgs(allocator);

    const img = try zigimg.image.Image.fromFile(allocator,&file);
    defer img.deinit();

    const width = @intCast(c_int,img.width);
    const height = @intCast(c_int,img.height);

    var window = c.SDL_CreateWindow("Examples: zigimg with SDL2", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, width, height, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC) orelse return error.CreateRenderer;
    defer c.SDL_DestroyRenderer(renderer);

    var texture = try utils.sdlTextureFromImage(renderer, img);
    var destination_rect = c.SDL_Rect{.x = 0, .y = 0, .w = width, .h = height};

    _ = c.SDL_SetRenderDrawColor(renderer, 0x80, 0x80, 0x80, 0x00);
    _ = c.SDL_RenderClear(renderer);
    _ = c.SDL_RenderCopy(renderer, texture,null,&destination_rect);
    c.SDL_RenderPresent(renderer);

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }
    }
}