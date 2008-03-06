require 'test/unit'
require File.join(File.dirname(__FILE__), '../lib/image_temp_file')

class ImageTest < Test::Unit::TestCase
  include MiniMagick
  
  def test_image_temp_file
    tmp = ImageTempFile.new('test')
    assert_match %r{^test}, File::basename(tmp.path)
    tmp = ImageTempFile.new('test.jpg')
    assert_match %r{^test}, File::basename(tmp.path)
    assert_match %r{\.jpg$}, File::basename(tmp.path)
  end
end
