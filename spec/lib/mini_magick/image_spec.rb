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
          begin
            image = described_class.open(image_url)
            expect(image).to be_valid
          rescue SocketError
          end
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
          expect(File.exists?(image.path)).to be_truthy
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
          image = described_class.new(subject.path) do |b|
            b.resize "100x100!"
          end
          expect(image.dimensions).to eq [100, 100]
        end
      end

      describe "equivalence" do
        subject(:image) { described_class.new(image_path) }
        let(:same_image) { described_class.new(image_path) }
        let(:other_image) { described_class.new(image_path(:exif)) }

        it "is #== and #eql? to itself" do
          expect(image).to eq(image)
          expect(image).to eql(image)
        end

        it "is #== and #eql? to an instance of the same image" do
          expect(image).to eq(same_image)
          expect(image).to eql(same_image)
        end

        it "is not #== nor #eql? to an instance of a different image" do
          expect(image).not_to eq(other_image)
          expect(image).not_to eql(other_image)
        end

        it "generates the same hash code for an instance of the same image" do
          expect(image.hash).to eq(same_image.hash)
        end

        it "generates different same hash codes for a different image" do
          expect(image.hash).not_to eq(other_image.hash)
        end
      end

      describe "#format" do
        subject { described_class.open(image_path(:jpg)) }

        it "changes the format of the photo" do
          expect { subject.format("png") }
            .to change { subject.type }
        end

        it "reformats an image with a given extension" do
          expect { subject.format('png') }
            .to change { File.extname(subject.path) }.to ".png"
        end

        it "creates the file with new extension" do
          subject.format('png')
          expect(File.exist?(subject.path)).to be_truthy
        end

        it "accepts a block of additional commands" do
          expect {
            subject.format("png") do |b|
              b.resize("100x100!")
            end
          }.to change { subject.dimensions }.to [100, 100]
        end

        it "works without an extension" do
          subject = described_class.open(image_path(:without_extension))
          expect { subject.format("png") }
            .to change { File.extname(subject.path) }.from("").to(".png")
        end

        it "deletes the previous tempfile" do
          old_path = subject.path.dup
          subject.format('png')
          expect(File.exist?(old_path)).to be_falsy
        end

        it "doesn't delete itself when formatted to the same format" do
          subject.format(subject.type.downcase)
          expect(File.exists?(subject.path)).to be_truthy
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

        it "returns self" do
          expect(subject.format('png')).to eq subject
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

        it "writes layers" do
          output_path = random_path(["", ".#{subject.type.downcase}"])
          subject = described_class.new(image_path(:gif))
          subject.frames.first.write(output_path)
          expect(described_class.new(output_path)).to be_valid
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
          expect(subject[:signature]).to match(/[[:alnum:]]{64}/)
        end

        it "supports string keys" do
          expect(subject["width"]).to be_a(Fixnum)
          expect(subject["height"]).to be_a(Fixnum)
          expect(subject["dimensions"]).to all(be_a(Fixnum))
          expect(subject["colorspace"]).to be_a(String)
          expect(subject["format"]).to match(/[A-Z]/)
          expect(subject['signature']).to match(/[[:alnum:]]{64}/)
        end

        it "reads exif" do
          subject = described_class.new(image_path(:exif))
          gps_latitude = subject.exif["GPSLatitude"].split(/\s*,\s*/)
          gps_longitude = subject.exif["GPSLongitude"].split(/\s*,\s*/)

          expect(subject["EXIF:ColorSpace"]).to eq "1"
          expect(gps_latitude.size).to eq 3
          expect(gps_longitude.size).to eq 3
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
        expect(subject.signature).to match(/[[:alnum:]]{64}/)
      end

      it "changes colorspace when called with an argument" do
        expect_any_instance_of(MiniMagick::Tool::Mogrify).to receive(:call)
        subject.colorspace("Gray")
      end

      it "changes size when called with an argument" do
        expect_any_instance_of(MiniMagick::Tool::Mogrify).to receive(:call)
        subject.size("20x20")
      end

      describe "#exif" do
        subject { described_class.new(image_path(:exif)) }

        it "returns a hash of EXIF data" do
          expect(subject.exif["DateTimeOriginal"]).to be_a(String)
        end

        it "decodes the ExifVersion" do
          expect(subject.exif["ExifVersion"]).to eq("0221")
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
          expect(jpg.mime_type).to eq 'image/jpeg'
        end
      end

      describe "#layers" do
        it "returns a list of images" do
          expect(subject.layers).to all(be_a(MiniMagick::Image))
          expect(subject.layers.first).to be_valid
        end

        it "returns multiple images for GIFs, PDFs and PSDs" do
          gif = described_class.new(image_path(:gif))
          psd = described_class.new(image_path(:psd))

          expect(gif.frames.count).to be > 1
          expect(psd.layers.count).to be > 1 unless MiniMagick.graphicsmagick?
        end

        it "returns one image for other formats" do
          jpg = described_class.new(image_path(:jpg))

          expect(jpg.layers.count).to eq 1
        end
      end

      describe "missing methods" do
        context "for a known method" do
          it "is executed by #method_missing" do
            expect { subject.resize '20x30!' }
              .to change { subject.dimensions }.to [20, 30]
          end

          it "returns self" do
            expect(subject.resize('20x30!')).to eq subject
          end

          it "can be responed to" do
            expect(subject.respond_to?(:resize)).to be_truthy
          end
        end

        context "for an unknown method" do
          it "fails with a NoMethodError" do
            expect { subject.foo }
              .to raise_error(NoMethodError, /MiniMagick::Image/)
          end

          it "cannot be responded to" do
            expect(subject.respond_to?(:foo)).to be_falsy
          end
        end
      end

      describe "#combine_options" do
        it "chains multiple options and executes them in one command" do
          expect {
            subject.combine_options { |c| c.resize '20x30!' }
          }.to change { subject.dimensions }.to [20, 30]
        end

        it "doesn't allow calling of #format" do
          expect { subject.combine_options { |c| c.format("png") } }
            .to raise_error(NoMethodError)
        end

        it "returns self" do
          expect(subject.combine_options {}).to eq subject
        end
      end

      describe "#composite" do
        let(:other_image) { described_class.open(image_path) }
        let(:mask) { described_class.open(image_path) }

        it "creates a composite of two images" do
          image = subject.composite(other_image)
          expect(image).to be_valid
        end

        it "creates a composite of two images with mask" do
          image = subject.composite(other_image, 'jpg', mask)
          expect(image).to be_valid
        end

        it "yields an optional block" do
          expect { |b| subject.composite(other_image, &b) }
            .to yield_with_args(an_instance_of(MiniMagick::Tool::Composite))
        end

        it "makes the composited image with the provided extension" do
          result = subject.composite(other_image, 'png')
          expect(result.path).to end_with ".png"

          result = subject.composite(other_image)
          expect(result.path).to end_with ".jpg"
        end
      end

      describe "#collapse!" do
        subject { described_class.open(image_path(:animation)) }

        it "collapses the image to one frame" do
          subject.collapse!
          expect(subject.identify.lines.count).to eq 1
        end

        it "keeps the extension" do
          expect { subject.collapse! }
            .not_to change { subject.type }
        end

        it "clears the info" do
          expect { subject.collapse! }
            .to change { subject.size }
        end

        it "returns self" do
          expect(subject.collapse!).to eq subject
        end
      end

      describe "#identify" do
        it "returns the output of identify" do
          expect(subject.identify).to match(subject.type)
        end

        it "yields an optional block" do
          output = subject.identify do |b|
            b.verbose
          end
          expect(output).to match("Format:")
        end
      end

      describe "#run_command" do
        it "runs the given command" do
          output = subject.run_command("identify", "-format", "%w", subject.path)
          expect(output).to eq subject.width.to_s
        end
      end
    end
  end
end
