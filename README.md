# sdl-example
Example usage of zigimg using SDL2. This library uses [SDL.zig](https://github.com/MasterQ32/SDL.zig) for SDL bindings. Be sure to check out the repository including the submodules.

## Usage
The executable takes one command line argument which is the relative path to an image file. This image is then displayed in a window on the screen if zigimg is able to read this image. For now only 24bit RGB and 32bit RGBA images are supported.
