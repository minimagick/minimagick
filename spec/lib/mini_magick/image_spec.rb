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
        described_class.open(SIMPLE_IMAGE_PATH)
      rescue => e
        expect(e.message).to match(/(No such file|not found)/)
      end
    end
  end

  describe 'ported from testunit', :ported => true do
    it 'reads image from blob' do
      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        image = described_class.read(f.read)
        expect(image).to be_valid
        image.destroy!
      end
    end

    it 'reads image from tempfile', :if => !MiniMagick::Utilities.windows? do
      tempfile = Tempfile.new('magick')

      File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
        tempfile.write(f.read)
        tempfile.rewind
      end

      image = described_class.read(tempfile)
      expect(image).to be_valid
      image.destroy!
    end

    # from https://github.com/minimagick/minimagick/issues/163
    it 'annotates image with whitespace' do
      image = described_class.open(SIMPLE_IMAGE_PATH)

      expect {
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
      }.to_not raise_error
    end

    it 'opens image' do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      expect(image).to be_valid
      image.destroy!
    end

    it 'reads image from buffer' do
      buffer = StringIO.new File.open(SIMPLE_IMAGE_PATH, 'rb') { |f| f.read }
      image = described_class.read(buffer)
      expect(image).to be_valid
      image.destroy!
    end

    describe '.create' do
      subject(:create) do
        described_class.create do |f|
          # Had to replace the old File.read with the following to work across all platforms
          f.write(File.open(SIMPLE_IMAGE_PATH, 'rb') { |fi| fi.read })
        end
      end

      it 'creates an image' do
        expect {
          image = create
          image.destroy!
        }.to_not raise_error
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
      expect {
        image = described_class.new(SIMPLE_IMAGE_PATH)
        image.destroy!
      }.to_not raise_error
    end

    it 'loads remote image' do
      image = described_class.open('http://upload.wikimedia.org/wikipedia/en/b/bc/Wiki.png')
      expect(image).to be_valid
      image.destroy!
    end

    it 'loads remote image with complex url' do
      image = described_class.open(
        'http://a0.twimg.com/a/1296609216/images/fronts/logo_withbird_home.png?extra=foo&plus=bar'
      )
      expect(image).to be_valid
      image.destroy!
    end

    it 'reformats an image with a given extension' do
      expect {
        image = described_class.open(CAP_EXT_PATH)
        image.format 'jpg'
      }.to_not raise_error
    end

    describe '#write' do
      it 'reformats a PSD with a given a extension and all layers' do
        expect {
          image = described_class.open(PSD_IMAGE_PATH)
          image.format('jpg', nil)
        }.to_not raise_error
      end

      it 'opens and writes an image' do
        output_path = 'output.gif'
        begin
          image = described_class.new(SIMPLE_IMAGE_PATH)
          image.write output_path
          expect(File.exist?(output_path)).to be(true)
        ensure
          File.delete output_path
        end
        image.destroy!
      end

      it 'opens and writes an image with space in its filename' do
        output_path = 'test output.gif'
        begin
          image = described_class.new(SIMPLE_IMAGE_PATH)
          image.write output_path

          expect(File.exist?(output_path)).to be(true)
        ensure
          File.delete output_path
        end
        image.destroy!
      end

      it 'writes an image with stream' do
        stream = StringIO.new
        image = described_class.open(SIMPLE_IMAGE_PATH)
        image.write("#{Dir.tmpdir}/foo.gif")
        image.write(stream)
        expect(described_class.read(stream.string)).to be_valid
        image.destroy!
      end

      describe 'validation' do
        let(:image) { described_class.new(SIMPLE_IMAGE_PATH) }
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
      image = described_class.new(NOT_AN_IMAGE_PATH)
      expect(image).not_to be_valid
      image.destroy!
    end

    it "raises error when opening a file that isn't an image" do
      expect {
        image = described_class.open(NOT_AN_IMAGE_PATH)
        image.destroy
      }.to raise_error(MiniMagick::Invalid)
    end

    it 'inspects image meta info' do
      image = described_class.new(SIMPLE_IMAGE_PATH)
      expect(image[:width]).to be(150)
      expect(image[:height]).to be(55)
      expect(image[:dimensions]).to match_array [150, 55]
      expect(image[:colorspace]).to be_an_instance_of(String)
      expect(image[:format]).to match(/^gif$/i)
      image.destroy!
    end

    it 'inspects an erroneus image meta info' do
      image = described_class.new(ERRONEOUS_IMAGE_PATH)
      expect(image[:width]).to be(10)
      expect(image[:height]).to be(10)
      expect(image[:dimensions]).to match_array [10, 10]
      expect(image[:format]).to eq 'JPEG'
      image.destroy!
    end

    it 'inspects meta info from tiff images' do
      image = described_class.new(TIFF_IMAGE_PATH)
      expect(image[:format].to_s.downcase).to eq 'tiff'
      expect(image[:width]).to be(50)
      expect(image[:height]).to be(41)
      image.destroy!
    end

    it 'inspects a gif with jpg format correctly' do
      image = described_class.new(GIF_WITH_JPG_EXT)
      expect(image[:format].to_s.downcase).to eq 'gif'
      image.destroy!
    end

    it 'resizes an image correctly' do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      image.resize '20x30!'

      expect(image[:width]).to be(20)
      expect(image[:height]).to be(30)
      expect(image[:format]).to match(/^gif$/i)
      image.destroy!
    end

    it 'resizes an image with minimum dimensions' do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      original_width, original_height = image[:width], image[:height]
      image.resize "#{original_width + 10}x#{original_height + 10}>"

      expect(image[:width]).to be original_width
      expect(image[:height]).to be original_height
      image.destroy!
    end

    it 'combines options to create an image with resize and blur' do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      image.combine_options do |c|
        c.resize '20x30!'
        c.blur '50'
      end

      expect(image[:width]).to be(20)
      expect(image[:height]).to be(30)
      expect(image[:format]).to match(/\Agif\z/i)
      image.destroy!
    end

    it "combines options to create an image even with minuses symbols on it's name it" do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      background = '#000000'
      expect {
        image.combine_options do |c|
          c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
          c.thumbnail '300x500>'
          c.background background
        end
      }.to_not raise_error
      image.destroy!
    end

    it 'inspects the EXIF of an image' do
      image = described_class.open(EXIF_IMAGE_PATH)
      expect(image['exif:ExifVersion']).to eq '0220'
      image = described_class.open(SIMPLE_IMAGE_PATH)
      expect(image['EXIF:ExifVersion']).to be_empty
      image.destroy!
    end

    it 'inspects the original at of an image' do
      image = described_class.open(EXIF_IMAGE_PATH)
      expect(image[:original_at]).to eq Time.local('2005', '2', '23', '23', '17', '24')
      image = described_class.open(SIMPLE_IMAGE_PATH)
      expect(image[:original_at]).to be_nil
      image.destroy!
    end

    it 'has the same path for tempfile and image' do
      image = described_class.open(TIFF_IMAGE_PATH)
      expect(image.instance_eval('@tempfile.path')).to eq image.path
      image.destroy!
    end

    it 'has the tempfile at path after format' do
      image = described_class.open(TIFF_IMAGE_PATH)
      image.format('png')
      expect(File.exist?(image.path)).to be(true)
      image.destroy!
    end

    it "hasn't previous tempfile at path after format" do
      image = described_class.open(TIFF_IMAGE_PATH)
      before = image.path.dup
      image.format('png')
      expect(File.exist?(before)).to be(false)
      image.destroy!
    end

    it 'changes the format of image with special characters', :if => !MiniMagick::Utilities.windows? do
      tempfile = Tempfile.new('magick with special! "chars\'')

      File.open(SIMPLE_IMAGE_PATH, 'rb') do |file|
        tempfile.write(file.read)
        tempfile.rewind
      end

      image = described_class.new(tempfile.path)
      image.format('png')
      expect(File.exist?(image.path)).to be(true)
      image.destroy!

      File.delete(image.path)
      tempfile.unlink
    end

    it 'raises exception when calling wrong method' do
      image = described_class.open(TIFF_IMAGE_PATH)
      expect { image.to_blog }.to raise_error(NoMethodError)
      image.to_blob
      image.destroy!
    end

    it 'can create a composite of two images' do
      image = described_class.open(EXIF_IMAGE_PATH)
      result = image.composite(described_class.open(TIFF_IMAGE_PATH)) do |c|
        c.gravity 'center'
      end
      expect(File.exist?(result.path)).to be(true)
    end

    # https://github.com/minimagick/minimagick/issues/212
    it 'can create a composite of two images with mask' do
      image = described_class.open(EXIF_IMAGE_PATH)
      result = image.composite(described_class.open(TIFF_IMAGE_PATH), 'jpg', described_class.open(PNG_PATH)) do |c|
        c.gravity 'center'
      end
      expect(File.exist?(result.path)).to be(true)
    end

    # https://github.com/minimagick/minimagick/issues/8
    it 'has issue 8 fixed' do
      image = described_class.open(SIMPLE_IMAGE_PATH)
      expect {
        image.combine_options do |c|
          c.sample '50%'
          c.rotate '-90>'
        end
      }.to_not raise_error
      image.destroy!
    end

    # https://github.com/minimagick/minimagick/issues/8
    it 'has issue 15 fixed' do
      expect {
        image = described_class.open(Pathname.new(SIMPLE_IMAGE_PATH))
        output = Pathname.new('test.gif')
        image.write(output)
      }.to_not raise_error
      FileUtils.rm('test.gif')
    end

    # https://github.com/minimagick/minimagick/issues/37
    it 'respects the language set' do
      original_lang = ENV['LANG']
      ENV['LANG'] = 'fr_FR.UTF-8'

      expect {
        image = described_class.open(NOT_AN_IMAGE_PATH)
        image.destroy
      }.to raise_error(MiniMagick::Invalid)

      ENV['LANG'] = original_lang
    end

    it 'can import pixels with default format' do
      columns = 325
      rows    = 200
      depth   = 16 # 16 bits (2 bytes) per pixel
      map     = 'gray'
      pixels  = Array.new(columns * rows) { |i| i }
      blob    = pixels.pack('S*') # unsigned short, native byte order
      image   = described_class.import_pixels(blob, columns, rows, depth, map)

      expect(image).to be_valid
      expect(image[:format].to_s.downcase).to eq 'png'
      expect(image[:width]).to eq columns
      expect(image[:height]).to eq rows
      image.write("#{Dir.tmpdir}/imported_pixels_image.png")
    end

    it 'can import pixels with custom format' do
      columns = 325
      rows    = 200
      depth   = 16 # 16 bits (2 bytes) per pixel
      map     = 'gray'
      format  = 'jpeg'
      pixels  = Array.new(columns * rows) { |i| i }
      blob    = pixels.pack('S*') # unsigned short, native byte order
      image   = described_class.import_pixels(blob, columns, rows, depth, map, format)

      expect(image).to be_valid
      expect(image[:format].to_s.downcase).to eq format
      expect(image[:width]).to eq columns
      expect(image[:height]).to eq rows
      image.write("#{Dir.tmpdir}/imported_pixels_image." + format)
    end

    it 'loads mimetype correctly' do
      gif        = described_class.open(SIMPLE_IMAGE_PATH)
      jpeg       = described_class.open(EXIF_IMAGE_PATH)
      png        = described_class.open(PNG_PATH)
      tiff       = described_class.open(TIFF_IMAGE_PATH)
      hidden_gif = described_class.open(GIF_WITH_JPG_EXT)

      expect(gif.mime_type).to eq 'image/gif'
      expect(jpeg.mime_type).to eq 'image/jpeg'
      expect(png.mime_type).to eq 'image/png'
      expect(tiff.mime_type).to eq 'image/tiff'
      expect(hidden_gif.mime_type).to eq 'image/gif'
    end

    it 'can flatten single layer PSD\'s' do 
      img = MiniMagick::Image.open(SINGLE_LAYER_PSD)

      expect {
        img.format('jpg', nil)
      }.to_not raise_error
    end
  end
end
