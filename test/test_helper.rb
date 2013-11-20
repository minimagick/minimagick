# encoding: UTF-8

require 'rubygems'
require 'test/unit'
require 'pathname'
require 'tempfile'
require 'rbconfig'
require File.expand_path('../../lib/mini_magick', __FILE__)


module MiniMagickTestFiles
  test_files = File.expand_path(File.dirname(__FILE__) + "/files")
  SIMPLE_IMAGE_PATH        = File.join(test_files, "/simple.gif")
  MINUS_IMAGE_PATH         = File.join(test_files, "/simple-minus.gif")
  SPECIAL_CHARS_IMAGE_PATH = File.join(test_files, "/special! _chars' )(-.gif")
  TIFF_IMAGE_PATH          = File.join(test_files, "/leaves (spaced).tiff")
  NOT_AN_IMAGE_PATH        = File.join(test_files, "/not_an_image.php")
  GIF_WITH_JPG_EXT         = File.join(test_files, "/actually_a_gif.jpg")
  EXIF_IMAGE_PATH          = File.join(test_files, "/trogdor.jpg")
  CAP_EXT_PATH             = File.join(test_files, "/trogdor_capitalized.JPG")
  ANIMATION_PATH           = File.join(test_files, "/animation.gif")
  PNG_PATH                 = File.join(test_files, "/png.png")
  COMP_IMAGE_PATH          = File.join(test_files, "/composited.jpg")
  ERRONEOUS_IMAGE_PATH     = File.join(test_files, "/erroneous.jpg")
end

module MiniMagickTestHelpers
  IS_WINDOWS               = RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
end
