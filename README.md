# MiniMagick

[![Build Status](https://travis-ci.org/minimagick/minimagick.svg?branch=master)](http://travis-ci.org/minimagick/minimagick)
[![Code Climate](https://codeclimate.com/github/minimagick/minimagick/badges/gpa.svg)](https://codeclimate.com/github/minimagick/minimagick)

A ruby wrapper for [ImageMagick](http://imagemagick.org/) or
[GraphicsMagick](http://www.graphicsmagick.org/) command line.

## Why?

I was using [RMagick](https://github.com/rmagick/rmagick) and loving it, but it
was eating up huge amounts of memory. Even a simple script would use over 100MB
of RAM. On my local machine this wasn't a problem, but on my hosting server the
ruby apps would crash because of their 100MB memory limit.

## Solution!

Using MiniMagick the ruby processes memory remains small (it spawns
ImageMagick's command line program mogrify which takes up some memory as well,
but is much smaller compared to RMagick). See [Thinking of switching from
RMagick?](#thinking-of-switching-from-rmagick) below.

MiniMagick gives you access to all the command line options ImageMagick has
(found [here](http://www.imagemagick.org/script/command-line-options.php)).

## Requirements

ImageMagick or GraphicsMagick command-line tool has to be installed. You can
check if you have it installed by running

```sh
$ convert -version
Version: ImageMagick 6.8.9-7 Q16 x86_64 2014-09-11 http://www.imagemagick.org
Copyright: Copyright (C) 1999-2014 ImageMagick Studio LLC
Features: DPC Modules
Delegates: bzlib fftw freetype jng jpeg lcms ltdl lzma png tiff xml zlib
```

MiniMagick has been tested on following Rubies:

* MRI 1.9.3
* MRI 2.0
* MRI 2.1
* MRI 2.2
* MRI 2.3
* Rubinius
* JRuby (1.7.18 and later)

## Installation

Add the gem to your Gemfile:

```ruby
gem "mini_magick"
```

## Information

* [API documentation](http://rubydoc.info/github/minimagick/minimagick)

## Usage

Let's first see a basic example of resizing an image.

```ruby
image = MiniMagick::Image.open("input.jpg")
image.path #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/magick20140921-75881-1yho3zc.jpg"
image.resize "100x100"
image.format "png"
image.write "output.png"
```

`MiniMagick::Image.open` makes a copy of the image, and further methods modify
that copy (the original stays untouched). We then
[resize](http://www.imagemagick.org/script/command-line-options.php#resize)
the image, and write it to a file. The writing part is necessary because
the copy is just temporary, it gets garbage collected when we lose reference
to the image.

`MiniMagick::Image.open` also accepts URLs.

```ruby
image = MiniMagick::Image.open("http://example.com/image.jpg")
image.contrast
image.write("from_internets.jpg")
```

On the other hand, if we want the original image to actually *get* modified,
we can use `MiniMagick::Image.new`.

```ruby
image = MiniMagick::Image.new("input.jpg")
image.path #=> "input.jpg"
image.resize "100x100"
# No calling #write, because it's no a copy
```

### Combine options

While using methods like `#resize` directly is convenient, if we use more
methods in this way, it quickly becomes inefficient, because it calls the
command on each methods call. `MiniMagick::Image#combine_options` takes
multiple options and from them builds one single command.

```ruby
image.combine_options do |b|
  b.resize "250x200>"
  b.rotate "-90"
  b.flip
end # the command gets executed
```

As a handy shortcut, `MiniMagick::Image.new` also accepts an optional block
which is used to `combine_options`.

```ruby
image = MiniMagick::Image.new("input.jpg") do |b|
  b.resize "250x200>"
  b.rotate "-90"
  b.flip
end # the command gets executed
```

The yielded builder is an instance of `MiniMagick::Tool::Mogrify`. To learn more
about its interface, see [Metal](#metal) below.

### Attributes

A `MiniMagick::Image` has various handy attributes.

```ruby
image.type        #=> "JPEG"
image.mime_type   #=> "image/jpeg"
image.width       #=> 250
image.height      #=> 300
image.dimensions  #=> [250, 300]
image.size        #=> 3451 (in bytes)
image.colorspace  #=> "DirectClass sRGB"
image.exif        #=> {"DateTimeOriginal" => "2013:09:04 08:03:39", ...}
image.resolution  #=> [75, 75]
image.signature   #=> "60a7848c4ca6e36b8e2c5dea632ecdc29e9637791d2c59ebf7a54c0c6a74ef7e"
```

If you need more control, you can also access [raw image
attributes](http://www.imagemagick.org/script/escape.php):

```ruby
image["%[gamma]"] # "0.9"
```

To get the all information about the image, MiniMagick gives you a handy method
(which just converts the output from `identify -verbose` into a Hash):

```ruby
image.details #=> {"Format" => "JPEG", "Mime type" => "image/jpeg", "Resolution" => "300x300", ...}
```

### Configuration

```ruby
MiniMagick.configure do |config|
  config.cli = :graphicsmagick
  config.timeout = 5
end
```

For a complete list of configuration options, see
[Configuration](http://rubydoc.info/github/minimagick/minimagick/MiniMagick/Configuration).

### Composite

MiniMagick also allows you to
[composite](http://www.imagemagick.org/script/composite.php) images:

```ruby
first_image  = MiniMagick::Image.new("first.jpg")
second_image = MiniMagick::Image.new("second.jpg")
result = first_image.composite(second_image) do |c|
  c.compose "Over"    # OverCompositeOp
  c.geometry "+20+20" # copy second_image onto first_image from (20, 20)
end
result.write "output.jpg"
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

### Image validation

By default, MiniMagick validates images each time it's opening them. It
validates them by running `identify` on them, and see if ImageMagick finds
them valid. This adds slight overhead to the whole processing. Sometimes it's
safe to assume that all input and output images are valid by default and turn
off validation:

```ruby
MiniMagick.configure do |config|
  config.validate_on_create = false
  config.validate_on_write = false
end
```

You can test whether an image is valid:

```ruby
image.valid?
image.validate! # raises MiniMagick::Invalid if image is invalid
```

### Logging

You can choose to log MiniMagick commands and their execution times:

```ruby
MiniMagick.logger.level = Logger::DEBUG
```
```
D, [2016-03-19T07:31:36.755338 #87191] DEBUG -- : [0.01s] identify /var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/mini_magick20160319-87191-1ve31n1.jpg
```

In Rails you'll probably want to set `MiniMagick.logger = Rails.logger`.

### Switching CLIs (ImageMagick \<=\> GraphicsMagick)

Default CLI is ImageMagick, but if you want to use GraphicsMagick, you can
specify it in configuration:

```rb
MiniMagick.configure do |config|
  config.cli = :graphicsmagick
end
```

If you're a real ImageMagick guru, you might want to use GraphicsMagick only
for certain processing blocks (because it's more efficient), or vice versa. You
can accomplish this with `.with_cli`:

```ruby
MiniMagick.with_cli(:graphicsmagick) do
  # Some processing that GraphicsMagick is better at
end
```

**WARNING**: If you're building a multithreaded web application, you should
change the CLI only on application startup. This is because the configuration is
global, so if you change it in a controller action, other threads in the same
process will also have their CLI changed, which could lead to race conditions.

### Metal

If you want to be close to the metal, you can use ImageMagick's command-line
tools directly.

```ruby
MiniMagick::Tool::Mogrify.new do |mogrify|
  mogrify.resize("100x100")
  mogrify.negate
  mogrify << "image.jpg"
end #=> `mogrify -resize 100x100 -negate image.jpg`

# OR

mogrify = MiniMagick::Tool::Mogrify.new
mogrify.resize("100x100")
mogrify.negate
mogrify << "image.jpg"
mogrify.call #=> `mogrify -resize 100x100 -negate image.jpg`
```

This way of using MiniMagick is highly recommended if you want to maximize
performance of your image processing. Here are some of the features.

#### Appending

The most basic way of building a command is appending strings:

```rb
MiniMagick::Tool::Convert.new do |convert|
  convert << "input.jpg"
  convert.merge! ["-resize", "500x500", "-negate"]
  convert << "output.jpg"
end
```

Note that it is important that every command you would pass to the command line
has to be separated with `<<`, e.g.:

```ruby
# GOOD
convert << "-resize" << "500x500"

# BAD
convert << "-resize 500x500"
```

Shell escaping is also handled for you. If an option has a value that has
spaces inside it, just pass it as a regular string.

```ruby
convert << "-distort"
convert << "Perspective"
convert << "0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35"
```
```
convert -distort Perspective '0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35'
```

#### Methods

Instead of passing in options directly, you can use Ruby methods:

```ruby
convert.resize("500x500")
convert.rotate(90)
convert.distort("Perspective", "0,0,0,0 0,45,0,45 69,0,60,10 69,45,60,35")
```

MiniMagick knows which options each tool has, so you will get an explicit
`NoMethodError` if you happen to have mispelled an option.

#### Chaining

Every method call returns `self`, so you can chain them to create logical groups.

```ruby
MiniMagick::Tool::Convert.new do |convert|
  convert << "input.jpg"
  convert.clone(0).background('gray').shadow('80x5+5+5')
  convert.negate
  convert << "output.jpg"
end
```

#### "Plus" options

```ruby
MiniMagick::Tool::Convert.new do |convert|
  convert << "input.jpg"
  convert.repage.+
  convert.distort.+("Perspective", "more args")
end
```
```
convert input.jpg +repage +distort Perspective 'more args'
```

#### Stacks

```ruby
MiniMagick::Tool::Convert.new do |convert|
  convert << "wand.gif"
  convert.stack do |stack|
    stack << "wand.gif"
    stack.rotate(30)
  end
  convert << "images.gif"
end
```
```
convert wand.gif \( wand.gif -rotate 90 \) images.gif
```

#### Passing STDIN

If you want to pass something to standard input, you can pass the `:stdin`
option to `#call`:

```ruby
identify = MiniMagick::Tool::Identify.new
identify.stdin # alias for `identify << "-"`
identify.call(stdin: image_content)
```

#### Capturing STDERR

Some MiniMagick tools such as `compare` output the result of the command on
standard error, even if the command succeeded. The result of
`MiniMagick::Tool#call` is always the standard output, but if you pass it a
block, it will yield the stdout, stderr and exit status of the command:

```rb
compare = MiniMagick::Tool::Compare.new
# build the command
compare.call do |stdout, stderr, status|
  # ...
end
```

## Limiting resources

ImageMagick supports a number of environment variables for controlling its
resource limits. For example, you can enforce memory or execution time limits by
setting the following variables in your application's process environment:

* `MAGICK_MEMORY_LIMIT=128MiB`
* `MAGICK_MAP_LIMIT=64MiB`
* `MAGICK_TIME_LIMIT=30`

For a full list of variables and description, see [ImageMagick's resources
documentation](http://www.imagemagick.org/script/resources.php).

## Troubleshooting

### Errors being raised when they shouldn't

This gem raises an error when ImageMagick returns a nonzero exit code.
Sometimes, however, ImageMagick returns nonzero exit codes when the command
actually went ok. In these cases, to avoid raising errors, you can add the
following configuration:

```rb
MiniMagick.configure do |config|
  config.whiny = false
end
```

If you're using the tool directly, you can pass `whiny: false` value to the
constructor:

```rb
MiniMagick::Tool::Identify.new(whiny: false) do |b|
  b.help
end
```

### `Errno::ENOMEM`

It can happen that, when dealing with very large images, the process runs out of
memory, and `Errno::ENOMEM` is raised in your code. In that case try installing
the [posix-spawn](https://github.com/rtomayko/posix-spawn) gem, and tell MiniMagick
to use it when executing shell commands.

```rb
MiniMagick.configure do |config|
  config.shell_api = "posix-spawn"
end
```

## Thinking of switching from RMagick?

Unlike RMagick, MiniMagick is a much thinner wrapper around ImageMagick.

* To piece together MiniMagick commands refer to the [Mogrify
  Documentation](http://www.imagemagick.org/script/mogrify.php). For instance
  you can use the `-flop` option as `image.flop`.
* Operations on a MiniMagick image tend to happen in-place as `image.trim`,
  whereas RMagick has both copying and in-place methods like `image.trim` and
  `image.trim!`.
* To open files with MiniMagick you use `MiniMagick::Image.open` as you would
  `Magick::Image.read`. To open a file and directly edit it, use
  `MiniMagick::Image.new`.
