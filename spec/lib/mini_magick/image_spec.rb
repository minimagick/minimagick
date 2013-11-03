require 'spec_helper'
require 'pathname'
require 'tempfile'

MiniMagick.processor = 'mogrify'

describe MiniMagick::Image do
  describe "ported from testunit", ported: true do
    it 'reads image from blob' do
      File.open(SIMPLE_IMAGE_PATH, "rb") do |f|
        image = MiniMagick::Image.read(f.read)
        image.valid?.should be true
        image.destroy!
      end
    end

    it 'reads image from tempfile' do
      tempfile = Tempfile.new('magick')

      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        tempfile.write(f.read)
        tempfile.rewind
      end

      image = MiniMagick::Image.read(tempfile)
      image.valid?.should be true
      image.destroy!
    end

    it 'opens image' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image.valid?.should be true
      image.destroy!
    end

    it 'reads image from buffer' do
      buffer = StringIO.new File.open(SIMPLE_IMAGE_PATH,"rb") { |f| f.read }
      image = MiniMagick::Image.read(buffer)
      image.valid?.should be true
      image.destroy!
    end

    it 'creates an image' do
      expect do
        image = MiniMagick::Image.create do |f|
          #Had to replace the old File.read with the following to work across all platforms
          f.write(File.open(SIMPLE_IMAGE_PATH,"rb") { |f| f.read })
        end
        image.destroy!
      end.to_not raise_error
    end

    it 'loads a new image' do
      expect do
        image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
        image.destroy!
      end.to_not raise_error
    end

    it 'loads remote image' do
      image = MiniMagick::Image.open("http://upload.wikimedia.org/wikipedia/en/b/bc/Wiki.png")
      image.valid?.should be true
      image.destroy!
    end

    it 'loads remote image with complex url' do
      image = MiniMagick::Image.open("http://a0.twimg.com/a/1296609216/images/fronts/logo_withbird_home.png?extra=foo&plus=bar")
      image.valid?.should be true
      image.destroy!
    end

    it 'reformats an image with a given extension' do
      expect do
        image = MiniMagick::Image.open(CAP_EXT_PATH)
        image.format "jpg"
      end.to_not raise_error
    end

    it 'opens and writes an image' do
      output_path = "output.gif"
      begin
        image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
        image.write output_path

        File.exists?(output_path).should be true
      ensure
        File.delete output_path
      end
      image.destroy!
    end
  end
end
