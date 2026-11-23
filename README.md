# MiniMagick
[![Gem Version](https://img.shields.io/gem/v/mini_magick.svg)](https://rubygems.org/gems/mini_magick)
[![Gem Downloads](https://img.shields.io/gem/dt/mini_magick.svg)](https://rubygems.org/gems/mini_magick)
[![CI](https://github.com/minimagick/minimagick/actions/workflows/ci.yml/badge.svg)](https://github.com/minimagick/minimagick/actions/workflows/ci.yml)

A ruby wrapper for the [ImageMagick](https://imagemagick.org/) command line.

## Why?

I was using [RMagick](https://github.com/rmagick/rmagick) and loving it, but it
was eating up huge amounts of memory. Even a simple script would use over 100MB
of RAM. On my local machine this wasn't a problem, but on my hosting server the
ruby apps would crash because of their 100MB memory limit.

## Solution!

Using MiniMagick the ruby processes memory remains small (it spawns
ImageMagick's command line programs, which take up some memory as well, but
much less compared to RMagick). See [Thinking of switching from
RMagick?](#thinking-of-switching-from-rmagick) below.

MiniMagick gives you access to all the command line options ImageMagick has
(found [here](https://imagemagick.org/script/command-line-options.php)).

## Requirements

ImageMagick command-line tool has to be installed. You can check if you have it
installed by running

```sh
$ magick -version
Version: ImageMagick 7.1.1-33 Q16-HDRI aarch64 22263 https://imagemagick.org
Copyright: (C) 1999 ImageMagick Studio LLC
License: https://imagemagick.org/script/license.php
Features: Cipher DPC HDRI Modules OpenMP(5.0)
Delegates (built-in): bzlib fontconfig freetype gslib heic jng jp2 jpeg jxl lcms lqr ltdl lzma openexr png ps raw tiff webp xml zlib zstd
Compiler: gcc (4.2)
```

## Installation

Add the gem to your Gemfile:

```sh
$ bundle add mini_magick
```

## Information

* [API documentation](https://rubydoc.info/gems/mini_magick)
* [Changelog](https://github.com/minimagick/minimagick/releases)

## Usage

Let's first see a basic example of resizing an image.

```rb
require "mini_magick"

image = MiniMagick::Image.open("input.jpg")
image.path #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20140921-75881-1yho3zc.jpg"
image.resize "100x100"
image.format "png"
image.write "output.png"
```

`MiniMagick::Image.open` makes a copy of the image, and further methods modify
that copy (the original stays untouched). We then
[resize](https://imagemagick.org/script/command-line-options.php#resize)
the image, and write it to a file. The writing part is necessary because
the copy is just temporary, it gets garbage collected when we lose reference
to the image. If you want to delete the temporary copy right away, you can call
`MiniMagick::Image#destroy!`.

`MiniMagick::Image.open` also accepts URLs, and options passed in will be
forwarded to [open-uri](https://github.com/ruby/open-uri).

```rb
image = MiniMagick::Image.open("http://example.com/image.jpg")
image.contrast
image.write("from_internets.jpg")
```

If the file extension cannot be determined from the path or URL, you can pass
it in explicitly:

```rb
image = MiniMagick::Image.open("http://example.com/image", ".jpg")
```

On the other hand, if we want the original image to actually *get* modified,
we can use `MiniMagick::Image.new`.

```rb
image = MiniMagick::Image.new("input.jpg")
image.path #=> "input.jpg"
image.resize "100x100"
# Not calling #write, because it's not a copy
```

### Reading from a blob or an IO

If you already have the image content in memory, or in an IO object, you can
use `MiniMagick::Image.read`, which copies it into a temporary file.

```rb
image = MiniMagick::Image.read(File.binread("input.jpg"))
image = MiniMagick::Image.read(File.open("input.jpg", "rb"))
image = MiniMagick::Image.read(io, ".jpg") # explicit file extension
```

### Writing

`MiniMagick::Image#write` accepts either a file path or an IO object, and
`MiniMagick::Image#to_blob` returns the image content as a binary string.

```rb
image.write("output.jpg")
image.write(io) # anything that responds to #write
image.to_blob   #=> "\xFF\xD8\xFF\xE0\x00\x10JFIF..."
```

### Combine options

While using methods like `#resize` directly is convenient, if we use more
methods in this way, it quickly becomes inefficient, because it calls the
command on each methods call. `MiniMagick::Image#combine_options` takes
multiple options and from them builds one single command.

```rb
image.combine_options do |b|
  b.resize "250x200>"
  b.rotate "-90"
  b.flip
end # the command gets executed
```

As a handy shortcut, `MiniMagick::Image.new` also accepts an optional block
which is used to `combine_options`.

```rb
image = MiniMagick::Image.new("input.jpg") do |b|
  b.resize "250x200>"
  b.rotate "-90"
  b.flip
end # the command gets executed
```

The yielded builder is an instance of `MiniMagick::Tool`. To learn more
about its interface, see [Tools](#tools) below.

### Changing format

Changing the image format is done with `MiniMagick::Image#format`, which
converts the image into a new file with the new extension, and updates the
image path.

```rb
image = MiniMagick::Image.open("input.png")
image.format "jpg"
image.path #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20140921-75881-1yho3zc.jpg"
```

Note that with `MiniMagick::Image.new` the original file is **deleted** and
replaced with the converted file, so use `MiniMagick::Image.open` if you want to
keep the original.

For multi-page images (e.g. GIFs or PDFs) only the first page is converted by
default. You can choose a different page, or pass `nil` to convert all pages:

```rb
image.format "png", 2   # converts the 3rd page
image.format "gif", nil # converts all pages
```

You can pass additional options which should be applied when reading the
image, as well as a block for further modifying the `convert` command:

```rb
image.format "png", 0, density: 300 do |convert|
  convert.background "white"
  convert.flatten
end
```

Because `-format` means something else to `mogrify`, `#format` cannot be called
inside `#combine_options`.

### Attributes

A `MiniMagick::Image` has various handy attributes.

```rb
image.type        #=> "JPEG"
image.width       #=> 250
image.height      #=> 300
image.dimensions  #=> [250, 300]
image.landscape?  #=> false
image.portrait?   #=> true
image.size        #=> 3451 (in bytes)
image.human_size  #=> "3451B"
image.colorspace  #=> "DirectClass sRGB"
image.exif        #=> {"DateTimeOriginal" => "2013:09:04 08:03:39", ...}
image.resolution  #=> [75, 75]
image.signature   #=> "60a7848c4ca6e36b8e2c5dea632ecdc29e9637791d2c59ebf7a54c0c6a74ef7e"
```

The attribute values are cached, and the cache is cleared whenever the image is
modified through MiniMagick. Two images are considered equal (`==`) when their
signatures match.

If you need more control, you can also access [raw image
attributes](https://imagemagick.org/script/escape.php):

```rb
image["%[gamma]"] # "0.9"
```

To get the all information about the image, MiniMagick gives you a handy method
which returns the output from `magick input.jpg json:`:

```rb
image.data #=>
# {
#   "format": "JPEG",
#   "mimeType": "image/jpeg",
#   "class": "DirectClass",
#   "geometry": {
#     "width": 200,
#     "height": 276,
#     "x": 0,
#     "y": 0
#   },
#   "resolution": {
#     "x": "300",
#     "y": "300"
#   },
#   "colorspace": "sRGB",
#   "channelDepth": {
#     "red": 8,
#     "green": 8,
#     "blue": 8
#   },
#   "quality": 92,
#   "properties": {
#     "date:create": "2016-07-11T19:17:53+08:00",
#     "date:modify": "2016-07-11T19:17:53+08:00",
#     "exif:ColorSpace": "1",
#     "exif:ExifImageLength": "276",
#     "exif:ExifImageWidth": "200",
#     "exif:ExifOffset": "90",
#     "exif:Orientation": "1",
#     "exif:ResolutionUnit": "2",
#     "exif:XResolution": "300/1",
#     "exif:YResolution": "300/1",
#     "icc:copyright": "Copyright (c) 1998 Hewlett-Packard Company",
#     "icc:description": "sRGB IEC61966-2.1",
#     "icc:manufacturer": "IEC http://www.iec.ch",
#     "icc:model": "IEC 61966-2.1 Default RGB colour space - sRGB",
#     "jpeg:colorspace": "2",
#     "jpeg:sampling-factor": "1x1,1x1,1x1",
#     "signature": "1b2336f023e5be4a9f357848df9803527afacd4987ecc18c4295a272403e52c1"
#   },
#   ...
# }
```

### Pixels

With MiniMagick you can retrieve a matrix of image pixels, where each member of
the matrix is a 3-element array of numbers between 0-255, one for each range of
the RGB color channels.

```rb
image = MiniMagick::Image.open("image.jpg")
pixels = image.get_pixels
pixels[3][2][1] # the green channel value from the 4th-row, 3rd-column pixel
```

You can also include the alpha channel by passing `"RGBA"`, in which case each
member will be a 4-element array:

```rb
pixels = image.get_pixels("RGBA")
pixels[3][2][3] # the alpha channel value from the 4th-row, 3rd-column pixel
```

It can also be called after applying transformations:

```rb
image = MiniMagick::Image.open("image.jpg")
image.crop "20x30+10+5"
image.colorspace "Gray"
pixels = image.get_pixels
```

In this example, the returned pixels should now have equal R, G, and B values.

### Pixels To Image

If you have a matrix of pixels (in the same format as returned by
`#get_pixels`), you can create an image from them:

```rb
image = MiniMagick::Image.open("input.jpg")
pixels = image.get_pixels
# ... modify pixels ...
dimension = [image.width, image.height]
depth = 8
map = "rgb"
image = MiniMagick::Image.get_image_from_pixels(pixels, dimension, map, depth, "jpg")
image.write("output.jpg")
```

If you instead have a binary string of raw pixel data, you can use
`MiniMagick::Image.import_pixels`:

```rb
image = MiniMagick::Image.import_pixels(blob, width, height, 8, "rgb", "png")
```

Note that both of these can be expensive for larger images.

### Composite

MiniMagick also allows you to
[composite](https://imagemagick.org/script/composite.php) images:

```rb
first_image  = MiniMagick::Image.new("first.jpg")
second_image = MiniMagick::Image.new("second.jpg")
result = first_image.composite(second_image) do |c|
  c.compose "Over"    # OverCompositeOp
  c.geometry "+20+20" # copy second_image onto first_image from (20, 20)
end
result.write "output.jpg"
```

The result is a new image in a temporary file, and neither of the source images
are modified. By default the result has the same format as the first image, but
you can choose a different output extension, and also pass a mask image:

```rb
result = first_image.composite(second_image, "png", mask_image)
```

### Layers/Frames/Pages

For multilayered images you can access its layers.

```rb
gif.frames #=> [...]
pdf.pages  #=> [...]
psd.layers #=> [...]

gif.frames.each_with_index do |frame, idx|
  frame.write("frame#{idx}.jpg")
end
```

To collapse a multilayered image to a single frame, you can use
`MiniMagick::Image#collapse!`:

```rb
gif.collapse!    # keeps only the first frame
gif.collapse!(2) # keeps only the 3rd frame
```

### Image validation

You can test whether an image is valid by running it through `identify`:

```rb
image.valid?
image.validate! # raises MiniMagick::Invalid if image is invalid
```

### Logging

You can choose to log MiniMagick commands and their execution times:

```rb
MiniMagick.logger.level = Logger::DEBUG
```
```
D, [2016-03-19T07:31:36.755338 #87191] DEBUG -- : [0.01s] magick identify /var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20160319-87191-1ve31n1.jpg
```

By default MiniMagick logs to standard output with `INFO` level, so commands
aren't logged. In Rails you'll probably want to set
`MiniMagick.logger = Rails.logger`.

### Errors

MiniMagick raises the following errors:

* `MiniMagick::Error` – when an ImageMagick command exits with a nonzero exit
  status, or the executable is not found
* `MiniMagick::TimeoutError` (subclass of `MiniMagick::Error`) – when an
  ImageMagick command exceeds the configured [timeout](#limiting-resources)
* `MiniMagick::Invalid` – when an image is invalid or its data can't be read
  (e.g. `#validate!`, `#width`)

## Tools

If you prefer not to use the `MiniMagick::Image` abstraction, you can use ImageMagick's command-line tools directly:

```rb
MiniMagick.convert do |convert|
  convert << "input.jpg"
  convert.resize("100x100")
  convert.negate
  convert << "output.jpg"
end #=> `magick input.jpg -resize 100x100 -negate output.jpg`

# OR

convert = MiniMagick.convert
convert << "input.jpg"
convert.resize("100x100")
convert.negate
convert << "output.jpg"
convert.call #=> `magick input.jpg -resize 100x100 -negate output.jpg`
```

This way of using MiniMagick is highly recommended if you want to maximize
performance of your image processing. There are class methods for each CLI
tool: `animate`, `compare`, `composite`, `conjure`, `convert`, `display`,
`identify`, `import`, `mogrify`, `montage` and `stream`. On ImageMagick 7 the
tools are executed through `magick` (e.g. `magick identify`), except
`MiniMagick.convert` which runs `magick` itself (`convert` is deprecated on
ImageMagick 7). On ImageMagick 6 the tools are executed directly (e.g.
`identify`, `convert`).

When called with a block, the command is executed at the end and its standard
output is returned. Otherwise the tool instance is returned, and the command is
executed with `#call`. You can inspect the built command with `#command`:

```rb
convert = MiniMagick.convert
convert << "input.jpg" << "output.png"
convert.command #=> ["magick", "input.jpg", "output.png"]
```

You can also check which ImageMagick version is being used:

```rb
MiniMagick.imagemagick7? #=> true
MiniMagick.cli_version   #=> "7.1.1-33"
```

### Appending

The most basic way of building a command is appending strings:

```rb
MiniMagick.convert do |convert|
  convert << "input.jpg"
  convert.merge! ["-resize", "500x500", "-negate"]
  convert << "output.jpg"
end
```

Note that it is important that every command you would pass to the command line
has to be separated with `<<`, e.g.:

```rb
# GOOD
convert << "-resize" << "500x500"

# BAD
convert << "-resize 500x500"
```

Commands are executed directly, without going through a shell, so you don't need
to escape anything. If an option has a value that has spaces inside it, just
pass it as a regular string.

```rb
convert << "-distort"
convert << "Perspective"
convert << "0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35"
```
```
magick -distort Perspective '0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35'
```

### Methods

Instead of passing in options directly, you can use Ruby methods. Underscores
in method names are converted to dashes.

```rb
convert.resize("500x500")
convert.rotate(90)
convert.auto_orient # -auto-orient
convert.distort("Perspective", "0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35")
```

There are also methods for [creation
operators](https://imagemagick.org/script/formats.php#pseudo), which are
added without a leading dash: `xc`, `canvas`, `logo`, `rose`, `gradient`,
`radial_gradient`, `plasma`, `pattern`, `text` and `pango`.

```rb
MiniMagick.convert do |convert|
  convert.size "100x100"
  convert.xc "white"
  convert << "output.png"
end
```
```
magick -size 100x100 xc:white output.png
```

### Chaining

Every method call returns `self`, so you can chain them to create logical groups.

```rb
MiniMagick.convert do |convert|
  convert << "input.jpg"
  convert.clone(0).background('gray').shadow('80x5+5+5')
  convert.negate
  convert << "output.jpg"
end
```

### "Plus" options

```rb
MiniMagick.convert do |convert|
  convert << "input.jpg"
  convert.repage.+
  convert.distort.+("Perspective", "more args")
end
```
```
magick input.jpg +repage +distort Perspective 'more args'
```

### Stacks

```rb
MiniMagick.convert do |convert|
  convert << "wand.gif"

  convert.stack do |stack|
    stack << "wand.gif"
    stack.rotate(30)
    stack.foo("bar", "baz")
  end
  # or
  convert.stack("wand.gif", { rotate: 30, foo: ["bar", "baz"] })

  convert << "images.gif"
end
```
```
magick wand.gif \( wand.gif -rotate 30 -foo bar baz \) images.gif
```

### STDIN and STDOUT

If you want to pass something to standard input, you can pass the `:stdin`
option to `#call`, either as a string or an IO object:

```rb
identify = MiniMagick.identify
identify.stdin # alias for "-"
identify.call(stdin: image_content)
# or
identify.call(stdin: File.open("image.jpg", "rb"))
```

MiniMagick also has `#stdout` alias for "-" for outputting file contents to
standard output:

```rb
content = MiniMagick.convert do |convert|
  convert << "input.jpg"
  convert.auto_orient
  convert.stdout # alias for "-"
end
```

Note that `#call` strips a trailing newline from the output. You can use the
block form described in [Capturing STDERR](#capturing-stderr) if you need the
exact output.

### Inheriting file descriptors

If the input is a file this process already has open, you can have the command
inherit the descriptor with the `:inherit_fds` option and name it as
`/dev/fd/N`, rather than writing out a copy for the command to read:

```rb
File.open("input.jpg", "rb") do |file|
  MiniMagick.identify(inherit_fds: [file]) do |identify|
    identify << "/dev/fd/#{file.fileno}"
  end
end
```

Each IO given to `:inherit_fds` is inherited at the same file descriptor
number. Without it the descriptor is close-on-exec, so `/dev/fd/N` does not
exist in the command. The command's own standard streams occupy 0, 1 and 2, so
those cannot be inherited.

### Capturing STDERR

Some MiniMagick tools such as `compare` output the result of the command on
standard error, even if the command succeeded. The result of
`MiniMagick::Tool#call` is always the standard output, but if you pass it a
block, it will yield the stdout, stderr and exit status of the command, and
standard error won't be forwarded to `$stderr`:

```rb
compare = MiniMagick.compare(errors: false)
# build the command
compare.call do |stdout, stderr, status|
  # ...
end
```

Note that `compare` exits with status 1 when the images are different, so you'll
want to pass `errors: false` to avoid an error being raised in that case.

### Command options

The following options can be passed either when creating the tool or to
`#call`, and they override the global [configuration](#configuration):

| Option         | Description                                                          |
| :------------- | :------------------------------------------------------------------- |
| `:errors`      | whether to raise an error on nonzero exit status                     |
| `:warnings`    | whether to forward standard error to `$stderr`                       |
| `:timeout`     | number of seconds after which the command is terminated              |
| `:stdin`       | string or IO object to write to the command's standard input         |
| `:inherit_fds` | IO objects whose file descriptors the command should inherit         |

```rb
MiniMagick.identify(errors: false, timeout: 5) { |b| b.help }
# or
MiniMagick.identify.help.call(errors: false, timeout: 5)
```

## Configuration

Here are the available configuration options with their default values:

```rb
MiniMagick.configure do |config|
  config.timeout = nil # number of seconds IM commands may take
  config.errors = true # raise errors on nonzero exit status
  config.warnings = true # forward warnings to standard error
  config.tmpdir = Dir.tmpdir # alternative directory for tempfiles
  config.logger = Logger.new($stdout) # where to log IM commands (INFO level)
  config.cli_prefix = nil # add prefix to all IM commands
  config.cli_env = {} # environment variables to set for IM commands
  config.restricted_env = false # when true, block IM commands from accessing system environment variables other than those in cli_env
  config.graphicsmagick = false # use GraphicsMagick instead of ImageMagick
end
```

For more information, see the
[Configuration](https://rubydoc.info/gems/mini_magick/MiniMagick/Configuration)
API documentation.

### GraphicsMagick

As of MiniMagick 5+, [GraphicsMagick](http://www.graphicsmagick.org/) isn't
officially supported. This means its installation won't be auto-detected, and no
attempts will be made to handle differences in GraphicsMagick API or output.

However, you can still configure MiniMagick to use it:

```rb
MiniMagick.configure do |config|
  config.graphicsmagick = true
end
```

Some MiniMagick features won't be supported, such as `MiniMagick::Image#data`
and `MiniMagick::Image#exif`.

### Limiting resources

ImageMagick supports a number of [environment variables] for controlling its
resource limits. For example, you can enforce memory or execution time limits by
setting the following:

```rb
MiniMagick.configure do |config|
  config.cli_env = {
    "MAGICK_MEMORY_LIMIT" => "128MiB",
    "MAGICK_MAP_LIMIT" => "64MiB",
    "MAGICK_TIME_LIMIT" => "30"
  }
end
```

For time limit you can also use the `timeout` configuration:

```rb
MiniMagick.configure do |config|
  config.timeout = 30 # 30 seconds
end
```

When the timeout is set, MiniMagick will both set `MAGICK_TIME_LIMIT` (taking
precedence over the value in `cli_env`) and terminate the command itself once
the timeout has elapsed, raising `MiniMagick::TimeoutError`. This is because
ImageMagick checks its time limit only periodically, so it may fire too late or
not at all depending on the operation.

### Restricting environment

By default, ImageMagick commands inherit all environment variables of the Ruby
process. If you don't want that, you can enable `restricted_env`, in which case
only `HOME`, `PATH` and `LANG` will be passed through, along with any
variables set in `cli_env`:

```rb
MiniMagick.configure do |config|
  config.restricted_env = true
  config.cli_env = { "MAGICK_MEMORY_LIMIT" => "128MiB" }
end
```

### Command prefix

You can prefix all commands with another command using `cli_prefix`, for
example to run them in a sandbox:

```rb
MiniMagick.configure do |config|
  config.cli_prefix = ["firejail", "--force"]
end

MiniMagick.identify.command #=> ["firejail", "--force", "magick", "identify"]
```

### Changing temporary directory

By default, MiniMagick creates temporary files (e.g. for
`MiniMagick::Image.open`) in `Dir.tmpdir`. You can change that directory:

```rb
MiniMagick.configure do |config|
  config.tmpdir = "/my/new/tmp_dir"
end
```

The directory must exist and must be writable. Note that this doesn't affect
where ImageMagick itself writes its temporary files, for which you can set
`MAGICK_TEMPORARY_PATH` in `cli_env`.

### Ignoring STDERR

If you're receiving warnings from ImageMagick that you don't care about, you
can avoid them being forwarded to standard error:

```rb
MiniMagick.configure do |config|
  config.warnings = false
end
```

### Avoiding raising errors

This gem raises an error when ImageMagick returns a nonzero exit code.
Sometimes, however, ImageMagick returns nonzero exit codes when the command
actually went ok. In these cases, to avoid raising errors, you can add the
following configuration:

```rb
MiniMagick.configure do |config|
  config.errors = false
end
```

You can also pass `errors: false` to individual commands:

```rb
MiniMagick.identify(errors: false) do |b|
  b.help
end
```

Timeouts will still raise `MiniMagick::TimeoutError` even when errors are
disabled.

## Thinking of switching from RMagick?

Unlike RMagick, MiniMagick is a much thinner wrapper around ImageMagick.

* To piece together MiniMagick commands refer to the [Mogrify
  Documentation](https://imagemagick.org/script/mogrify.php). For instance
  you can use the `-flop` option as `image.flop`.
* Operations on a MiniMagick image tend to happen in-place as `image.trim`,
  whereas RMagick has both copying and in-place methods like `image.trim` and
  `image.trim!`.
* To open files with MiniMagick you use `MiniMagick::Image.open` as you would
  `Magick::Image.read`. To open a file and directly edit it, use
  `MiniMagick::Image.new`.

[environment variables]: https://imagemagick.org/script/resources.php#environment
