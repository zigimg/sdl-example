const c = @import("sdl2");
const std = @import("std");
const zigimg = @import("zigimg");
const Allocator = std.mem.Allocator;

/// Convert a zigimg.Image into an SDL Texture
/// # Arguments
/// * `renderer`: the renderer onto which to generate the texture.
/// Use the same renderer to display that texture.
/// * `image`: the image. This must have either 24 bit RGB color storage or 32bit ARGB
/// # Returns
/// An SDL Texture. The texture must be destroyed by the caller to free its memory.
pub fn sdlTextureFromImage(renderer: * c.SDL_Renderer, image : zigimg.image.Image) ! *c.SDL_Texture {
    
    const pxinfo = try PixelInfo.from(image);
    // if I don't do the trick with breaking inside the switch,
    // then it says, the return value of the switch is ignored,
    // which seems strange to me...    
    // TODO: ask about this on the discord... 
    const data : *c_void = blk: {if (image.pixels) |storage| {
        switch(storage) {
            .Argb32 => |argb32| break :blk @ptrCast(*c_void,argb32.ptr),
            .Rgb24 => |rgb24| break :blk @ptrCast(*c_void,rgb24.ptr),
            else => return error.InvalidColorStorage,
        }
    } else {
        return error.EmptyColorStorage;
    }};

    const surface =  c.SDL_CreateRGBSurfaceFrom(
        data,
        @intCast(c_int,image.width),
        @intCast(c_int,image.height),
        pxinfo.bits,
        pxinfo.pitch,
        pxinfo.pixelmask.red,
        pxinfo.pixelmask.green,
        pxinfo.pixelmask.blue,
        pxinfo.pixelmask.alpha);
    if(surface == null) {
        return error.CreateRgbSurface;
    }
    defer c.SDL_FreeSurface(surface);

    var texture = c.SDL_CreateTextureFromSurface(renderer,surface);
    if (texture) |non_null_texture| {
        return non_null_texture;
    } else {
        return error.CreateTexture;
    }
}

/// a helper structure that contains some info about the pixel layout
const PixelInfo = struct {
    /// bits per pixel
    bits : c_int,
    /// the pitch (see SDL docs, this is the width of the image times the size per pixel in byte)
    pitch : c_int,
    /// the pixelmask for the (A)RGB storage
    pixelmask : PixelMask,

    const Self = @This();

    pub fn from(image : zigimg.image.Image) !Self {
        const Sizes = struct {bits : c_int, pitch : c_int};
        const sizes : Sizes = switch( image.pixels orelse return error.EmptyColorStorage)  {
            .Argb32 =>  Sizes{.bits = 32, .pitch= 4*@intCast(c_int,image.width)},
            .Rgb24 =>   Sizes{.bits = 24,  .pitch = 3*@intCast(c_int,image.width)},
            else => return error.InvalidColorStorage,
        };
        return Self {
            .bits = @intCast(c_int,sizes.bits),
            .pitch = @intCast(c_int,sizes.pitch),
            .pixelmask = try PixelMask.fromColorStorage(image.pixels orelse return error.EmptyColorStorage)
        };
    }

};

/// helper structure for getting the pixelmasks out of an image
const PixelMask = struct {
    red : u32,
    green : u32,
    blue : u32,
    alpha : u32,

    const Self = @This();
    /// construct a pixelmask given the colorstorage.
    /// *Attention*: right now only works for 24bit RGB and 32bit ARGB storage.
    pub fn fromColorStorage(storage : zigimg.color.ColorStorage) !Self {
        switch(storage) {
            .Argb32 => return Self {
                .red   = 0x00ff0000,
                .green = 0x0000ff00,
                .blue  = 0x000000ff,
                .alpha = 0xff000000,
                },
            .Rgb24 => return Self {
                .red   = 0xff0000,
                .green = 0x00ff00,
                .blue  = 0x0000ff,
                .alpha = 0,
                },
            else => return error.InvalidColorStorage,
        }
    }
};

pub fn fileFromProcessArgs(allocator : *std.mem.Allocator) !std.fs.File {
    var iter = std.process.args();

    const first = iter.next(allocator); //first argument is the name of the executable. Throw that away.
    if(first) |exe_name_or_error| {
        allocator.free(try exe_name_or_error);
    }

    var image_filename :[:0]u8= undefined;
    if(iter.next(allocator)) |arg_or_error| {
        image_filename = try arg_or_error;
    } else {
        std.log.err("Expected 1 argument, found 0! Specify the relative path of the image to display as the argument to this executable.", .{});
        return error.NoImageSpecified;
    }
    defer allocator.free(image_filename);
    std.log.info("Trying to open image file \'{s}\'", .{image_filename});

    return try std.fs.cwd().openFile(image_filename, .{});
}