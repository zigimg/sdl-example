const SDL = @import("sdl2");
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
pub fn sdlTextureFromImage(renderer: SDL.Renderer, image: zigimg.image.Image) !SDL.Texture {
    const pxinfo = try PixelInfo.from(image);
    const data: *c_void = blk: {
        if (image.pixels) |storage| {
            switch (storage) {
                .Argb32 => |argb32| break :blk @ptrCast(*c_void, argb32.ptr),
                .Rgb24 => |rgb24| break :blk @ptrCast(*c_void, rgb24.ptr),
                else => return error.InvalidColorStorage,
            }
        } else {
            return error.EmptyColorStorage;
        }
    };

    const surfaceptr = SDL.c.SDL_CreateRGBSurfaceFrom(data, @intCast(c_int, image.width), @intCast(c_int, image.height), pxinfo.bits, pxinfo.pitch, pxinfo.pixelmask.red, pxinfo.pixelmask.green, pxinfo.pixelmask.blue, pxinfo.pixelmask.alpha);
    if (surfaceptr == null) {
        return error.CreateRgbSurface;
    }

    const surface = SDL.Surface{ .ptr = surfaceptr };
    defer surface.destroy();

    return try SDL.createTextureFromSurface(renderer, surface);
}

/// Convert a zigimg.Image into an SDL Texture
/// This image achieves the same effect as sdlTextureFromImage, but it uses the color
/// iterator provided by the image.
/// # Arguments
/// * `renderer`: the renderer onto which to generate the texture.
/// Use the same renderer to display that texture.
/// * `image`: the image. This must have either 24 bit RGB color storage or 32bit ARGB
/// # Returns
/// An SDL Texture. The texture must be destroyed by the caller to free its memory.
pub fn sdlTextureFromImageUsingColorIterator(renderer: SDL.Renderer, image: zigimg.image.Image) !SDL.Texture {
    const surface_ptr = SDL.c.SDL_CreateRGBSurfaceWithFormat(0, @intCast(c_int, image.width), @intCast(c_int, image.height), 32, SDL.c.SDL_PIXELFORMAT_RGBA8888);
    if (surface_ptr == null) {
        return error.CreateRgbSurface;
    }
    const surface = SDL.Surface{ .ptr = surface_ptr };
    defer surface.destroy();

    var color_iter = image.iterator();

    if (surface.ptr.pixels == null) {
        return error.NullPixelSurface;
    }
    var pixels = @ptrCast([*]u8, surface.ptr.pixels);
    var offset: usize = 0;

    while (color_iter.next()) |fcol| {
        pixels[offset] = @floatToInt(u8, @round(fcol.A * 255));
        pixels[offset + 1] = @floatToInt(u8, @round(fcol.B * 255));
        pixels[offset + 2] = @floatToInt(u8, @round(fcol.G * 255));
        pixels[offset + 3] = @floatToInt(u8, @round(fcol.R * 255));
        offset += 4;
    }

    return try SDL.createTextureFromSurface(renderer, surface);
}

/// a helper structure that contains some info about the pixel layout
const PixelInfo = struct {
    /// bits per pixel
    bits: c_int,
    /// the pitch (see SDL docs, this is the width of the image times the size per pixel in byte)
    pitch: c_int,
    /// the pixelmask for the (A)RGB storage
    pixelmask: PixelMask,

    const Self = @This();

    pub fn from(image: zigimg.image.Image) !Self {
        const Sizes = struct { bits: c_int, pitch: c_int };
        const sizes: Sizes = switch (image.pixels orelse return error.EmptyColorStorage) {
            .Argb32 => Sizes{ .bits = 32, .pitch = 4 * @intCast(c_int, image.width) },
            .Rgb24 => Sizes{ .bits = 24, .pitch = 3 * @intCast(c_int, image.width) },
            else => return error.InvalidColorStorage,
        };
        return Self{ .bits = @intCast(c_int, sizes.bits), .pitch = @intCast(c_int, sizes.pitch), .pixelmask = try PixelMask.fromColorStorage(image.pixels orelse return error.EmptyColorStorage) };
    }
};

/// helper structure for getting the pixelmasks out of an image
const PixelMask = struct {
    red: u32,
    green: u32,
    blue: u32,
    alpha: u32,

    const Self = @This();
    /// construct a pixelmask given the colorstorage.
    /// *Attention*: right now only works for 24bit RGB and 32bit ARGB storage.
    pub fn fromColorStorage(storage: zigimg.color.ColorStorage) !Self {
        switch (storage) {
            .Argb32 => return Self{
                .red = 0x00ff0000,
                .green = 0x0000ff00,
                .blue = 0x000000ff,
                .alpha = 0xff000000,
            },
            .Rgb24 => return Self{
                .red = 0xff0000,
                .green = 0x00ff00,
                .blue = 0x0000ff,
                .alpha = 0,
            },
            else => return error.InvalidColorStorage,
        }
    }
};

/// the program configuration
pub const ProgramConfig = struct {
    /// the image file we want to display with sdl
    image_file: std.fs.File,
    /// the conversion strategy we want to apply to get from image data to a texture
    image_conversion: Image2TexConversion,
};

/// the conversion algorithm
pub const Image2TexConversion = enum {
    /// use the color storage of the image directly
    buffer,
    /// use the color iterator
    color_iterator,
};

/// a quick&dirty command line parser
pub fn parseProcessArgs(allocator: *std.mem.Allocator) !ProgramConfig {
    var iter = std.process.args();

    const first = iter.next(allocator); //first argument is the name of the executable. Throw that away.
    if (first) |exe_name_or_error| {
        allocator.free(try exe_name_or_error);
    }

    var first_argument: [:0]u8 = undefined;
    if (iter.next(allocator)) |arg_or_error| {
        first_argument = try arg_or_error;
    } else {
        std.log.err("Unknown or too few command line arguments!", .{});
        printUsage();
        return error.UnknownCommandLine;
    }
    defer allocator.free(first_argument);

    var file: std.fs.File = undefined;
    var conversion: Image2TexConversion = Image2TexConversion.buffer;
    if (std.ascii.eqlIgnoreCase(first_argument, "--color-iter")) {
        var second_argument: [:0]u8 = undefined;
        if (iter.next(allocator)) |arg_or_error| {
            second_argument = try arg_or_error;
        } else {
            std.log.err("Expected image file name!", .{});
            printUsage();
            return error.NoImageSpecified;
        }
        defer allocator.free(second_argument);
        file = try std.fs.cwd().openFile(second_argument, .{});
        conversion = Image2TexConversion.color_iterator;
        std.log.info("Using color iterator for conversion", .{});
    } else {
        file = try std.fs.cwd().openFile(first_argument, .{});
    }

    return ProgramConfig{
        .image_file = file,
        .image_conversion = conversion,
    };
}

pub fn printUsage() void {
    std.log.info("Usage: sdl-example [--color-iter] image\n\timage\t\trelative path to an image file which will be displayed\n\t--color-iter\tspecify that the color iterator should be used to convert the image to a texture.", .{});
}
