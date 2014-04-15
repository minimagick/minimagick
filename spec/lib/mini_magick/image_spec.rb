require 'spec_helper'
require 'pathname'
require 'tempfile'

MiniMagick.processor = 'mogrify'

describe MiniMagick::Image do
  context 'when ImageMagick and GraphicsMagick are both unavailable' do
    before do
      MiniMagick::Utilities.expects(:which).at_least_once.returns(nil)
      MiniMagick.instance_variable_set(:@processor, nil)
      @old_path = ENV['PATH']
      ENV['PATH'] = ''
    end

    after do
      ENV['PATH'] = @old_path
    end

    it "raises an exception with 'No such file' in the message" do
      begin
        MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      rescue Exception => e
        e.message.should match(/(No such file|not found)/)
      end
    end
  end

  describe 'ported from testunit', ported: true do
    it 'reads image from blob' do
      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        image = MiniMagick::Image.read(f.read)
        image.valid?.should be true
        image.destroy!
      end
    end

    it 'reads image from tempfile', if: !MiniMagick::Utilities.windows? do
      tempfile = Tempfile.new('magick')

      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        tempfile.write(f.read)
        tempfile.rewind
      end

      image = MiniMagick::Image.read(tempfile)
      image.valid?.should be true
      image.destroy!
    end

    # from https://github.com/minimagick/minimagick/issues/163
    it 'annotates image with whitespace' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)

      expect do
        message = 'a b'

        image.combine_options do |c|
          c.gravity 'SouthWest'
          c.fill 'white'
          c.stroke 'black'
          c.strokewidth '2'
          c.pointsize '48'
          c.interline_spacing '-9'
          c.annotate '0', message
        end
      end.to_not raise_error
    end

    it 'opens image' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image.valid?.should be true
      image.destroy!
    end

    it 'reads image from buffer' do
      buffer = StringIO.new File.open(SIMPLE_IMAGE_PATH, 'rb') { |f| f.read }
      image = MiniMagick::Image.read(buffer)
      image.valid?.should be true
      image.destroy!
    end

    describe '.create' do
      subject(:create) do
        MiniMagick::Image.create do |f|
          # Had to replace the old File.read with the following to work across all platforms
          f.write(File.open(SIMPLE_IMAGE_PATH, 'rb') { |f| f.read })
        end
      end

      it 'creates an image' do
        expect do
          image = create
          image.destroy!
        end.to_not raise_error
      end

      describe 'validation' do
        before do
          @old_validate = MiniMagick.validate_on_create
          MiniMagick.validate_on_create = validate
        end

        context 'MiniMagick.validate_on_create = true' do
          let(:validate) { true }

          it 'validates image' do
            described_class.any_instance.expects(:valid?).returns(true)
            create
          end
        end

        context 'MiniMagick.validate_on_create = false' do
          let(:validate) { false }

          it 'skips validation' do
            described_class.any_instance.expects(:valid?).never
            create
          end
        end

        after { MiniMagick.validate_on_create = @old_validate }
      end
    end

    it 'loads a new image' do
      expect do
        image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
        image.destroy!
      end.to_not raise_error
    end

    it 'loads remote image' do
      image = MiniMagick::Image.open('http://upload.wikimedia.org/wikipedia/en/b/bc/Wiki.png')
      image.valid?.should be true
      image.destroy!
    end

    it 'loads remote image with complex url' do
      image = MiniMagick::Image.open('http://a0.twimg.com/a/1296609216/images/fronts/logo_withbird_home.png?extra=foo&plus=bar')
      image.valid?.should be true
      image.destroy!
    end

    it 'reformats an image with a given extension' do
      expect do
        image = MiniMagick::Image.open(CAP_EXT_PATH)
        image.format 'jpg'
      end.to_not raise_error
    end

    describe '#write' do
      it 'reformats a PSD with a given a extension and all layers' do
        expect do
          image = MiniMagick::Image.open(PSD_IMAGE_PATH)
          image.format('jpg', nil)
        end.to_not raise_error
      end

      it 'opens and writes an image' do
        output_path = 'output.gif'
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
        output_path = 'test output.gif'
        begin
          image = MiniMagick::Image.new(SIMPLE_IMAGE_PATH)
          image.write output_path

          File.exist?(output_path).should be true
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

      describe 'validation' do
        let(:image) { MiniMagick::Image.new(SIMPLE_IMAGE_PATH) }
        let(:output_path) { 'output.gif' }

        before do
          @old_validate = MiniMagick.validate_on_write
          MiniMagick.validate_on_write = validate
        end

        subject(:write) { image.write output_path }

        context 'MiniMagick.validate_on_write = true' do
          let(:validate) { true }

          it 'runs post-validation' do
            image.expects(:run_command).with('identify', output_path)
            write
          end
        end

        context 'MiniMagick.validate_on_write = false' do
          let(:validate) { false }

          it 'runs post-validation' do
            image.expects(:run_command).never
            write
          end
        end

        after do
          image.destroy!
          File.delete output_path
          MiniMagick.validate_on_write = @old_validate
        end
      end
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
      image.resize '20x30!'

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
        c.resize '20x30!'
        c.blur '50'
      end

      image[:width].should be 20
      image[:height].should be 30
      image[:format].should match(/^gif$/i)
      image.destroy!
    end

    it "combines options to create an image even with minuses symbols on it's name it" do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      background = '#000000'
      expect do
        image.combine_options do |c|
          c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
          c.thumbnail '300x500>'
          c.background background
        end
      end.to_not raise_error
      image.destroy!
    end

    it 'inspects the EXIF of an image' do
      image = MiniMagick::Image.open(EXIF_IMAGE_PATH)
      image['exif:ExifVersion'].should == '0220'
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image['EXIF:ExifVersion'].should == ''
      image.destroy!
    end

    it 'inspects the original at of an image' do
      image = MiniMagick::Image.open(EXIF_IMAGE_PATH)
      image[:original_at].should == Time.local('2005', '2', '23', '23', '17', '24')
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      image[:original_at].should be nil
      image.destroy!
    end

    it 'has the same path for tempfile and image' do
      image = MiniMagick::Image.open(TIFF_IMAGE_PATH)
      image.instance_eval('@tempfile.path').should == image.path
      image.destroy!
    end

    it 'has the tempfile at path after format' do
      image = MiniMagick::Image.open(TIFF_IMAGE_PATH)
      image.format('png')
      File.exist?(image.path).should be true
      image.destroy!
    end

    it "hasn't previous tempfile at path after format" do
      image = MiniMagick::Image.open(TIFF_IMAGE_PATH)
      before = image.path.dup
      image.format('png')
      File.exist?(before).should be false
      image.destroy!
    end

    it 'changes the format of image with special characters', if: !MiniMagick::Utilities.windows? do
      tempfile = Tempfile.new('magick with special! "chars\'')

      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        tempfile.write(f.read)
        tempfile.rewind
      end

      image = MiniMagick::Image.new(tempfile.path)
      image.format('png')
      File.exist?(image.path).should be true
      image.destroy!

      File.delete(image.path)
      tempfile.unlink
    end

    it 'raises exception when calling wrong method' do
      image = MiniMagick::Image.open(TIFF_IMAGE_PATH)
      expect { image.to_blog }.to raise_error(NoMethodError)
      image.to_blob
      image.destroy!
    end

    it 'can create a composite of two images' do
      if MiniMagick.valid_version_installed?
        image = MiniMagick::Image.open(EXIF_IMAGE_PATH)
        result = image.composite(MiniMagick::Image.open(TIFF_IMAGE_PATH)) do |c|
          c.gravity 'center'
        end
        File.exist?(result.path).should be true
      else
        puts "Need at least version #{MiniMagick.minimum_image_magick_version} of ImageMagick"
      end
    end

    # https://github.com/minimagick/minimagick/issues/8
    it 'has issue 8 fixed' do
      image = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      expect do
        image.combine_options do |c|
          c.sample '50%'
          c.rotate '-90>'
        end
      end.to_not raise_error
      image.destroy!
    end

    # https://github.com/minimagick/minimagick/issues/8
    it 'has issue 15 fixed' do
      expect do
        image = MiniMagick::Image.open(Pathname.new(SIMPLE_IMAGE_PATH))
        output = Pathname.new('test.gif')
        image.write(output)
      end.to_not raise_error
      FileUtils.rm('test.gif')
    end

    # https://github.com/minimagick/minimagick/issues/37
    it 'respects the language set' do
      original_lang = ENV['LANG']
      ENV['LANG'] = 'fr_FR.UTF-8'

      expect  do
        image = MiniMagick::Image.open(NOT_AN_IMAGE_PATH)
        image.destroy
      end.to raise_error(MiniMagick::Invalid)

      ENV['LANG'] = original_lang
    end

    it 'can import pixels with default format' do
      columns = 325
      rows = 200
      depth = 16 # 16 bits (2 bytes) per pixel
      map = 'gray'
      pixels = Array.new(columns * rows) { |i| i }
      blob = pixels.pack('S*') # unsigned short, native byte order
      image = MiniMagick::Image.import_pixels(blob, columns, rows, depth, map)
      image.valid?.should be true
      image[:format].to_s.downcase.should == 'png'
      image[:width].should == columns
      image[:height].should == rows
      image.write("#{Dir.tmpdir}/imported_pixels_image.png")
    end

    it 'can import pixels with custom format' do
      columns = 325
      rows = 200
      depth = 16 # 16 bits (2 bytes) per pixel
      map = 'gray'
      format = 'jpeg'
      pixels = Array.new(columns * rows) { |i| i }
      blob = pixels.pack('S*') # unsigned short, native byte order
      image = MiniMagick::Image.import_pixels(blob, columns, rows, depth, map, format)
      image.valid?.should be true
      image[:format].to_s.downcase.should == format
      image[:width].should == columns
      image[:height].should == rows
      image.write("#{Dir.tmpdir}/imported_pixels_image." + format)
    end

    it 'loads mimetype correctly' do
      gif =         MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
      jpeg =        MiniMagick::Image.open(EXIF_IMAGE_PATH)
      png =         MiniMagick::Image.open(PNG_PATH)
      tiff =        MiniMagick::Image.open(TIFF_IMAGE_PATH)
      hidden_gif =  MiniMagick::Image.open(GIF_WITH_JPG_EXT)

      gif.mime_type.should == 'image/gif'
      jpeg.mime_type.should == 'image/jpeg'
      png.mime_type.should == 'image/png'
      tiff.mime_type.should == 'image/tiff'
      hidden_gif.mime_type == 'image/gif'
    end
  end
end 
