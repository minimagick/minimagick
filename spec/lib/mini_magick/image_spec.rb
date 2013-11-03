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

    it 'opens and writes an image with space in its filename' do
      output_path = "test output.gif"
      begin
        image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
        image.write output_path

        File.exists?(output_path).should be true
      ensure
        File.delete output_path
      end
      image.destroy!
    end

    it 'writes an image with stream' do
      stream = StringIO.new
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image.write("#{Dir.tmpdir}/foo.gif")
      image.write(stream)
      MiniMagick::Image.read(stream.string).valid?.should be true
      image.destroy!
    end

    it 'tells when an image is invalid' do
      image = MiniMagick::Image.new(NOT_AN_IMAGE_PATH)
      image.valid?.should be false
      image.destroy!
    end

    it "raises error when opening a file that isn't an image" do
      expect do
        image = MiniMagick::Image.open(NOT_AN_IMAGE_PATH)
        image.destroy
      end.to raise_error(MiniMagick::Invalid)
    end

    it 'inspects image meta info' do
      image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
      image[:width].should be 150
      image[:height].should be 55
      image[:dimensions].should == [150, 55]
      image[:colorspace].should be_an_instance_of(String)
      image[:format].should match(/^gif$/i)
      image.destroy!
    end

    it 'inspects an erroneus image meta info' do
      image = MiniMagick::Image.new(ERRONEOUS_IMAGE_PATH)
      image[:width].should be 10
      image[:height].should be 10
      image[:dimensions].should == [10, 10]
      image[:format].should == 'JPEG'
      image.destroy!
    end

    it 'inspects meta info from tiff images' do
      image = MiniMagick::Image.new(TIFF_IMAGE_PATH)
      image[:format].to_s.downcase.should == 'tiff'
      image[:width].should be 50
      image[:height].should be 41
      image.destroy!
    end

    it 'inspects a gif with jpg format correctly' do
      image = MiniMagick::Image.new(GIF_WITH_JPG_EXT)
      image[:format].to_s.downcase.should == 'gif'
      image.destroy!
    end

    it 'resizes an image correctly' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image.resize "20x30!"

      image[:width].should be 20
      image[:height].should be 30
      image[:format].should match(/^gif$/i)
      image.destroy!
    end

    it 'resizes an image with minimum dimensions' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      original_width, original_height = image[:width], image[:height]
      image.resize "#{original_width + 10}x#{original_height + 10}>"

      image[:width].should be original_width
      image[:height].should be original_height
      image.destroy!
    end

    it 'combines options to create an image with resize and blur' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image.combine_options do |c|
        c.resize "20x30!"
        c.blur "50"
      end

      image[:width].should be 20
      image[:height].should be 30
      image[:format].should match(/^gif$/i)
      image.destroy!
    end

    it "combines options to create an image even with minuses symbols on it's name it" do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      background = "#000000"
      expect do
        image.combine_options do |c|
          c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
          c.thumbnail "300x500>"
          c.background background
        end
      end.to_not raise_error
      image.destroy!
    end

    it "combines options in image named with special characters" do
      image = MiniMagick::Image.new(SPECIAL_CHARS_IMAGE_PATH)
      expect do
        image.combine_options("identify") do |c|
          c.ping
        end
      end.to_not raise_error
      image.destroy!
    end

    it "inspects the EXIF of an image" do
      image = MiniMagick::Image.open(EXIF_IMAGE_PATH)
      image["exif:ExifVersion"].should == '0220'
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image["EXIF:ExifVersion"].should == ''
      image.destroy!
    end
  end
end
