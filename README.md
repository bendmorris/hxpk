This is a Haxe port of the libGDX Texture Packer, which packs image assets into 
texture atlases for efficient rendering. libGDX is released under the Apache 2 
license; see it on [GitHub](https://github.com/libgdx/libgdx) for more 
information and a full list of contributors. hxpk is a full port and includes 
all features of the original, including whitespace removal, alpha bleed 
correction, and more. You can read more about the original on the [libGDX GitHub 
wiki](https://github.com/libgdx/libgdx/wiki/Texture-packer).

hxpk differs from the original in that it can also be used to create textures 
from embedded assets at runtime. In other words, you can generate images after a 
program has started (for example, using the svg library to rasterize an SVG at 
an appropriate resolution for the current device) and then create a texture 
atlas from those images.

hxpk currently requires OpenFL and uses BitmapData for image processing.


Using hxpk
----------

You can run hxpk with:

    haxelib run hxpk

If no other arguments are supplied, usage instructions will be displayed.


Building
--------

If you downloaded hxpk from source, you'll have to first build the command line 
tool. To do so, simply navigate to the hxpk directory and run

    haxe build.hxml