require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'mocha/api'
require 'mini_magick'

RSpec.configure do |config|
  config.mock_framework = :mocha
  config.color          = true
  config.formatter      = 'documentation'
  config.raise_errors_for_deprecations!
end

test_files = File.expand_path(File.dirname(__FILE__) + '/files')

SIMPLE_IMAGE_PATH    = test_files + '/simple.gif'
MINUS_IMAGE_PATH     = test_files + '/simple-minus.gif'
TIFF_IMAGE_PATH      = test_files + '/leaves (spaced).tiff'
NOT_AN_IMAGE_PATH    = test_files + '/not_an_image.php'
GIF_WITH_JPG_EXT     = test_files + '/actually_a_gif.jpg'
EXIF_IMAGE_PATH      = test_files + '/trogdor.jpg'
CAP_EXT_PATH         = test_files + '/trogdor_capitalized.JPG'
PNG_PATH             = test_files + '/png.png'
ERRONEOUS_IMAGE_PATH = test_files + '/erroneous.jpg'
PSD_IMAGE_PATH       = test_files + '/layers.psd'
