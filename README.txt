= MiniMagick

* http://github.com/probablycorey/mini_magick`

== DESCRIPTION:

A ruby wrapper for ImageMagick command line.

== FEATURES/PROBLEMS:

I was using RMagick and loving it, but it was eating up huge amounts of memory. A simple script like this...

Magick::read("image.jpg") do |f|
 f.write("manipulated.jpg")
end

...would use over 100 Megs of Ram. On my local machine this wasn't a problem, but on my hosting server the ruby apps would crash because of their 100 Meg memory limit.

Solution!
---------
Using MiniMagick the ruby processes memory remains small (it spawns ImageMagick's command line program mogrify which takes up some memory as well, but is much smaller compared to RMagick)

MiniMagick gives you access to all the commandline options ImageMagick has (Found here http://www.imagemagick.org/script/mogrify.php)

== SYNOPSIS:

Want to make a thumbnail from a file...

image = MiniMagick::Image.from_file("input.jpg")
image.resize "100x100"
image.write("output.jpg")

Want to make a thumbnail from a blob...

image = MiniMagick::Image.from_blob(blob)
image.resize "100x100"
image.write("output.jpg")

Need to combine several options?

image = MiniMagick::Image.from_file("input.jpg")
image.combine_options do |c|
  c.sample "50%"
  c.rotate "-90>"
end
image.write("output.jpg")

Want to manipulate an image at its source (You won't have to write it out because the transformations are done on that file)

image = MiniMagick::Image.new("input.jpg")
image.resize "100x100"

Want to get some meta-information out?

image = MiniMagick::Image.from_file("input.jpg")
image[:width] # will get the width (you can also use :height and :format)
image["EXIF:BitsPerSample"] # It also can get all the EXIF tags
image["%m:%f %wx%h"] # Or you can use one of the many options of the format command found here http://www.imagemagick.org/script/command-line-options.php#format

== REQUIREMENTS:

You must have ImageMagick installed.

== INSTALL:

sudo gem install mini_magick

For Rails
---------

If want to use as a plugin, just drop the files into RAILS_ROOT/plugins/
If you installed this as a gem, then to get it to work add <require "mini_magick"> to RAILS_ROOT/config/environment.rb

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
