require "spec_helper"
require "pathname"
require "tempfile"
require "fileutils"
require "stringio"

["ImageMagick", "GraphicsMagick"].each do |cli|
  RSpec.context "With #{cli}", cli: cli.downcase.to_sym do
    describe MiniMagick::Image do
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
        let(:dimensions) { [325, 200] }
        let(:depth)      { 16 } # 16 bits (2 bytes) per pixel
        let(:map)        { 'gray' }
        let(:pixels)     { Array.new(dimensions.inject(:*)) { |i| i } }
        let(:blob)       { pixels.pack('S*') } # unsigned short, native byte order

        it "can import pixels with default format" do
          image = described_class.import_pixels(blob, *dimensions, depth, map)

          expect(image).to be_valid
          expect(image.type).to eq 'PNG'
          expect(image.dimensions).to eq dimensions
        end

        it "can import pixels with custom format" do
          image = described_class.import_pixels(blob, *dimensions, depth, map, 'jpeg')

          expect(image).to be_valid
          expect(image.type).to eq 'JPEG'
          expect(image.dimensions).to eq dimensions
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
          expect { create(image_path(:not)) }
            .to raise_error(MiniMagick::Invalid)
        end

        it "doesn't validate image if validation is disabled" do
          allow(MiniMagick).to receive(:validate_on_create).and_return(false)
          expect { create(image_path(:not)) }
            .not_to raise_error
        end
      end

      describe "#initialize" do
        it "initializes a new image" do
          image = described_class.new(image_path)
          expect(image).to be_valid
        end

        it "accepts a block which it passes on to #combine_options" do
          copy = described_class.open(image_path)
          image = described_class.new(copy.path) do |b|
            b.resize "100x100!"
          end
          expect(image.dimensions).to eq [100, 100]
        end
      end

      describe "#format" do
        subject { described_class.open(image_path(:jpg)) }

        it "changes the format of the photo" do
          expect { subject.format("png") }
            .to change { subject.type }
        end

        it "reformats an image with a given extension" do
          expect { subject.format 'png' }
            .to change { File.extname(subject.path) }.to ".png"
        end

        it "creates the file with new extension" do
          subject.format('png')
          expect(File.exist?(subject.path)).to eq true
        end

        it "deletes the previous tempfile" do
          old_path = subject.path.dup
          subject.format('png')
          expect(File.exist?(old_path)).to eq false
        end

        it "reformats multi-image formats to multiple images" do
          subject = described_class.open(image_path(:animation))
          subject.format('jpg', nil)
          expect(Dir[subject.path.sub('.', '*.')]).not_to be_empty
        end

        it "reformats multi-image formats to a single image" do
          subject = described_class.open(image_path(:animation))
          subject.format('jpg')
          expect(subject).to be_valid
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
          expect(subject[:width]).to be_a(Fixnum)
          expect(subject[:height]).to be_a(Fixnum)
          expect(subject[:dimensions]).to all(be_a(Fixnum))
          expect(subject[:colorspace]).to be_a(String)
          expect(subject[:format]).to match(/[A-Z]/)
        end

        it "supports string keys" do
          expect(subject["width"]).to be_a(Fixnum)
          expect(subject["height"]).to be_a(Fixnum)
          expect(subject["dimensions"]).to all(be_a(Fixnum))
          expect(subject["colorspace"]).to be_a(String)
          expect(subject["format"]).to match(/[A-Z]/)
        end

        it "reads exif" do
          subject = described_class.new(image_path(:exif))
          expect(subject["EXIF:ColorSpace"]).to eq "1"
        end

        it "passes unknown values directly to -format" do
          expect(subject["%w %h"].split.map(&:to_i)).to eq [subject[:width], subject[:height]]
        end
      end

      it "has attributes" do
        expect(subject.type).to match(/^[A-Z]+$/)
        expect(subject.mime_type).to match(/^image\/[a-z]+$/)
        expect(subject.width).to be_a(Fixnum).and be_nonzero
        expect(subject.height).to be_a(Fixnum).and be_nonzero
        expect(subject.dimensions).to all(be_a(Fixnum))
        expect(subject.size).to be_a(Fixnum).and be_nonzero
        expect(subject.colorspace).to be_a(String)
        expect(subject.resolution).to all(be_a(Fixnum))
      end

      describe "#exif" do
        subject { described_class.new(image_path(:exif)) }

        it "returns a hash of EXIF data" do
          expect(subject.exif["DateTimeOriginal"]).to be_a(String)
        end
      end

      describe "#resolution" do
        it "accepts units", skip_cli: :graphicsmagick do
          expect(subject.resolution("PixelsPerCentimeter"))
            .not_to eq subject.resolution("PixelsPerInch")
        end
      end

      describe "#mime_type" do
        it "returns the correct mime type" do
          jpg = described_class.new(image_path(:jpg))
          gif = described_class.new(image_path(:gif))

          expect(jpg.mime_type).to eq 'image/jpeg'
          expect(gif.mime_type).to eq 'image/gif'
        end
      end

      describe "#method_missing" do
        it "executes the command correctly" do
          subject.resize '20x30!'
          expect(subject.dimensions).to eq [20, 30]
        end
      end

      describe "#combine_options" do
        it "chains multiple options and executes them in one command" do
          subject.combine_options do |c|
            c.resize '20x30!'
            c.blur '50'
          end

          expect(subject.dimensions).to eq [20, 30]
        end

        it "clears the info" do
          expect {
            subject.combine_options { |c| c.resize '20x30!' }
          }.to change { subject.width }
        end
      end

      describe "#composite" do
        let(:other_image) { described_class.open(image_path) }
        let(:mask) { described_class.open(image_path) }

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
    end
  end
end
