const std = @import("std");
const c = @import("sdl2");
const zigimg = @import("zigimg");
const utils = @import("utils.zig");


/// read all images in the assets folder and render them 
/// on a square raster. The images will be stretched/squeezed to fit the raster.
pub fn main() anyerror!void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _=gpa.deinit();
    var allocator : *std.mem.Allocator = &gpa.allocator;


    _= c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();


    std.log.info("Command line arguments:",.{});
    var iter = std.process.args();

    const first = iter.next(allocator); //first argument is the name of the executable. Throw that away.
    if(first) |exe_name_or_error|{
        allocator.free(try exe_name_or_error);
    }

    var image_filename :[:0]u8= undefined;
    if(iter.next(allocator)) |arg_or_error| {
        image_filename = try arg_or_error;
    } else {
        std.log.err("Expected 1 argument, found 0. Specify the relative path of the image to display as the first argument!", .{});
        return error.NoImageSpecified;
    }
    defer allocator.free(image_filename);
    std.log.info("Trying to open image \'{s}\'", .{image_filename});

    var file = try std.fs.cwd().openFile(image_filename, .{});
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