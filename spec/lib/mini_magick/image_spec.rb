require "spec_helper"
require "pathname"
require "tempfile"
require "fileutils"
require "stringio"

RSpec.describe MiniMagick::Image do
  subject { described_class.open(image_path) }

  describe ".read" do
    it "reads image from String" do
      string = File.binread(image_path)
      image = described_class.read(string)
      expect(image).to be_valid
    end

    it "reads image from StringIO" do
      stringio = StringIO.new(File.binread(image_path))
      image = described_class.read(stringio)
      expect(image).to be_valid
    end

    it "reads image from tempfile" do
      tempfile = Tempfile.open('magick')
      FileUtils.cp image_path, tempfile.path
      image = described_class.read(tempfile)
      expect(image).to be_valid
    end
  end

  describe ".import_pixels" do
    it "can import pixels with default format" do
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
    end

    it "can import pixels with custom format" do
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
    end
  end

  describe ".open" do
    it "makes a copy of the image" do
      image = described_class.open(image_path)
      expect(image.path).not_to eq image_path
      expect(image).to be_valid
    end

    it "accepts a Pathname" do
      image = described_class.open(Pathname(image_path))
      expect(image).to be_valid
    end

    it "loads a remote image" do
      image = described_class.open(image_url)
      expect(image).to be_valid
    end

    it "validates the image" do
      expect { described_class.open(image_path(:not)) }
        .to raise_error(MiniMagick::Invalid)
    end
  end

  describe ".create" do
    def create(path = image_path)
      described_class.create do |f|
        f.write(File.binread(path))
      end
    end

    it "creates an image" do
      image = create
      expect(File.exists?(image.path)).to eq true
    end

    it "validates the image if validation is set" do
      allow(MiniMagick).to receive(:validate_on_create).and_return(true)
      expect { create(image_path(:erroneous)) }
        .to raise_error(MiniMagick::Invalid)
    end

    it "doesn't validate image if validation is disabled" do
      allow(MiniMagick).to receive(:validate_on_create).and_return(false)
      expect { create(image_path(:erroneous)) }
        .not_to raise_error
    end
  end

  describe "#initialize" do
    it "initializes a new image" do
      image = described_class.new(image_path)
      expect(image).to be_valid
    end
  end

  describe "#format" do
    it "reformats an image with a given extension" do
      image = described_class.open(image_path(:capitalized_ext))
      image.format 'jpg'
      expect(image.path).to match /\.jpg$/
    end

    it "creates the file with new extension" do
      image = described_class.open(image_path)
      image.format('png')
      expect(File.exist?(image.path)).to eq true
    end

    it "deletes the previous tempfile" do
      image = described_class.open(image_path)
      old_path = image.path
      image.format('png')
      expect(File.exist?(old_path)).to eq false
    end

    it "reformats a PSD with a given a extension and all layers" do
      image = described_class.open(image_path(:psd))
      image.format('jpg', nil)
    end

    it "can flatten single layer PSD's" do
      image = described_class.open(image_path(:single_layer_psd))
      image.format('jpg', nil)
      expect(image).to be_valid
    end

    it "resets the info" do
      expect { subject.format("png") }
        .to change { subject[:format] }
    end
  end

  describe "#write" do
    it "writes the image" do
      output_path = random_path("test output")
      subject.write(output_path)
      expect(described_class.new(output_path)).to be_valid
    end

    it "writes an image with stream" do
      output_stream = StringIO.new
      subject.write(output_stream)
      expect(described_class.read(output_stream.string)).to be_valid
    end

    it "accepts a Pathname" do
      output_path = Pathname(random_path)
      subject.write(output_path)
      expect(described_class.new(output_path.to_s)).to be_valid
    end
  end

  describe "#valid?" do
    it "returns true when image is valid" do
      image = described_class.new(image_path)
      expect(image).to be_valid
    end

    it "returns false when image is not valid" do
      image = described_class.new(image_path(:not))
      expect(image).not_to be_valid
    end
  end

  describe "#[]" do
    it "inspects image meta info" do
      expect(subject[:width]).to eq(150)
      expect(subject[:height]).to eq(55)
      expect(subject[:dimensions]).to match_array [150, 55]
      expect(subject[:colorspace]).to be_an_instance_of(String)
      expect(subject[:format]).to match(/^gif$/i)
    end

    it "supports string keys for dimension attributes" do
      expect(subject["width"]).to eq(150)
      expect(subject["height"]).to eq(55)
      expect(subject["dimensions"]).to match_array [150, 55]
    end

    it "inspects a gif with jpg format correctly" do
      image = described_class.new(image_path(:gif_with_jpg_ext))
      expect(image[:format].to_s.downcase).to eq 'gif'
    end

    it "inspects the EXIF of an image" do
      image = described_class.open(image_path(:exif))
      expect(image['exif:ExifVersion']).to eq '0220'
      image = described_class.open(image_path)
      expect(image['EXIF:ExifVersion']).to be_empty
    end

    it "inspects the original at of an image" do
      image = described_class.open(image_path(:exif))
      expect(image[:original_at]).to eq Time.local('2005', '2', '23', '23', '17', '24')
      image = described_class.open(image_path)
      expect(image[:original_at]).to be_nil
    end
  end

  describe "#method_missing" do
    it "executes the command correctly" do
      subject.resize '20x30!'
      expect(subject[:dimensions]).to eq [20, 30]
    end
  end

  describe "#combine_options" do
    it "chains multiple options and executes them in one command" do
      subject.combine_options do |c|
        c.resize '20x30!'
        c.blur '50'
      end

      expect(subject[:dimensions]).to eq [20, 30]
    end

    it "clears the info" do
      expect {
        subject.combine_options { |c| c.resize '20x30!' }
      }.to change { subject[:width] }
    end
  end

  describe "#composite" do
    let(:other_image) { described_class.open(image_path) }
    let(:mask) { described_class.open(image_path(:png)) }

    it "creates a composite of two images" do
      result = subject.composite(other_image) do |c|
        c.gravity 'center'
      end
      expect(File.exist?(result.path)).to eq(true)
    end

    it "creates a composite of two images with mask" do
      result = subject.composite(other_image, 'jpg', mask) do |c|
        c.gravity 'center'
      end
      expect(File.exist?(result.path)).to eq(true)
    end

    it "makes the composited image with the provided extension" do
      result = subject.composite(other_image, 'png')
      expect(File.extname(result.path)).to eq ".png"

      result = subject.composite(other_image)
      expect(File.extname(result.path)).to eq ".jpg"
    end
  end

  describe "#mime_type" do
    it "returns the correct mime type" do
      gif        = described_class.new(image_path(:gif))
      jpeg       = described_class.new(image_path(:jpg))
      png        = described_class.new(image_path(:png))
      tiff       = described_class.new(image_path(:tiff))
      hidden_gif = described_class.new(image_path(:gif_with_jpg_ext))

      expect(gif.mime_type).to eq 'image/gif'
      expect(jpeg.mime_type).to eq 'image/jpeg'
      expect(png.mime_type).to eq 'image/png'
      expect(tiff.mime_type).to eq 'image/tiff'
      expect(hidden_gif.mime_type).to eq 'image/gif'
    end
  end

  # https://github.com/minimagick/minimagick/issues/37
  it "doesn't break when parsing different language" do
    original_lang = ENV['LANG']
    ENV['LANG'] = 'fr_FR.UTF-8'

    expect { image = described_class.open(image_path(:not)) }.
      to raise_error(MiniMagick::Invalid)

    ENV['LANG'] = original_lang
  end
end
