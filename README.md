# MiniMagick

A ruby wrapper for ImageMagick or GraphicsMagick command line.

Tested on the following Rubies: MRI 1.8.7, 1.9.2, 1.9.3, 2.0.0, REE, JRuby, Rubinius.

[![Build Status](https://secure.travis-ci.org/minimagick/minimagick.png)](http://travis-ci.org/minimagick/minimagick)
[![Code Climate](https://codeclimate.com/github/minimagick/minimagick.png)](https://codeclimate.com/github/minimagick/minimagick)
[![Inline docs](http://inch-pages.github.io/github/minimagick/minimagick.png)](http://inch-pages.github.io/github/minimagick/minimagick)

## Installation

Add the gem to your Gemfile:

```ruby
gem "mini_magick"
```

## Information

* [Rdoc](http://rubydoc.info/github/minimagick/minimagick)


## Why?

I was using RMagick and loving it, but it was eating up huge amounts
of memory. Even a simple script would use over 100MB of Ram. On my
local machine this wasn't a problem, but on my hosting server the
ruby apps would crash because of their 100MB memory limit.

## Solution!

Using MiniMagick the ruby processes memory remains small (it spawns
ImageMagick's command line program mogrify which takes up some memory
as well, but is much smaller compared to RMagick)

MiniMagick gives you access to all the command line options ImageMagick
has (Found here http://www.imagemagick.org/script/mogrify.php)


## Examples

Want to make a thumbnail from a file...

```ruby
image = MiniMagick::Image.open("input.jpg")
image.resize "100x100"
image.write  "output.jpg"
```

Want to make a thumbnail from a blob...

```ruby
image = MiniMagick::Image.read(blob)
image.resize "100x100"
image.write  "output.jpg"
```

Got an incoming IOStream?

```ruby
image = MiniMagick::Image.read(stream)
```

Want to make a thumbnail of a remote image?

```ruby
image = MiniMagick::Image.open("http://www.google.com/images/logos/logo.png")
image.resize "5x5"
image.format "gif"
image.write "localcopy.gif"
```

Need to combine several options?

```ruby
image = MiniMagick::Image.open("input.jpg")
image.combine_options do |c|
  c.sample "50%"
  c.rotate "-90>"
end
image.write "output.jpg"
```

Want to composite two images? Super easy! (Aka, put a watermark on!)

```ruby
image = Image.open("original.png")
result = image.composite(Image.open("watermark.png", "jpg")) do |c|
  c.gravity "center"
end
result.write "my_output_file.jpg"
```

Want to manipulate an image at its source (You won't have to write it
out because the transformations are done on that file)

```ruby
image = MiniMagick::Image.new("input.jpg")
image.resize "100x100"
```

Want to get some meta-information out?

```ruby
image = MiniMagick::Image.open("input.jpg")
image[:width]               # will get the width (you can also use :height and :format)
image["EXIF:BitsPerSample"] # It also can get all the EXIF tags
image["%m:%f %wx%h"]        # Or you can use one of the many options of the format command
```

For more on the format command see
http://www.imagemagick.org/script/command-line-options.php#format

Want to composite (merge) two images?

```ruby
first_image = MiniMagick::Image.open "first.jpg"
second_image = MiniMagick::Image.open "second.jpg"
result = first_image.composite(second_image) do |c|
  c.compose "Over" # OverCompositeOp
  c.geometry "+20+20" # copy second_image onto first_image from (20, 20)
end
result.write "output.jpg"
```

## Thinking of switching from RMagick?

Unlike [RMagick](http://rmagick.rubyforge.org), MiniMagick is a much thinner wrapper around ImageMagick.

* To piece together MiniMagick commands refer to the [Mogrify Documentation](http://www.imagemagick.org/script/mogrify.php). For instance you can use the `-flop` option as `image.flop`.
* Operations on a MiniMagick image tend to happen in-place as `image.trim`, whereas RMagick has both copying and in-place methods like `image.trim` and `image.trim!`.
* To open files with MiniMagick you use `MiniMagick::Image.open` as you would `Magick::Image.read`. To open a file and directly edit it, use `MiniMagick::Image.new`.

## Windows Users

When passing in a blob or IOStream, Windows users need to make sure they read the file in as binary.

```ruby
# This way works on Windows
buffer = StringIO.new(File.open(IMAGE_PATH,"rb") { |f| f.read })
MiniMagick::Image.read(buffer)

# You may run into problems doing it this way
buffer = StringIO.new(File.read(IMAGE_PATH))
```

## Using GraphicsMagick

Simply set

```ruby
MiniMagick.processor = :gm
```

And you are sorted.

# Requirements

You must have ImageMagick or GraphicsMagick installed.

# Caveats

Version 3.5 doesn't work in Ruby 1.9.2-p180. If you are running this Ruby version use the 3.4 version of this gem.
