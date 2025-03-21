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
      expect(File.extname(image.path)).to eq File.extname(image_path)
    end

    it "accepts a Pathname" do
      image = described_class.open(Pathname(image_path))
      expect(image).to be_valid
    end

    it "accepts a non-ascii filename" do
      image = described_class.open(image_path(:non_ascii_filename))
      expect(image).to be_valid
    end

    it "loads a remote image" do
      expect_any_instance_of(URI::HTTP).to receive(:open).and_yield(File.open(image_path, "rb"))
      image = described_class.open("http://example.com/image.jpg")
      expect(image).to be_valid
      expect(File.extname(image.path)).to eq ".jpg"
    end

    it "accepts open-uri options" do
      expect_any_instance_of(URI::HTTP).to receive(:open)
        .with({ "Foo" => "Bar" })
        .and_yield(File.open(image_path, "rb"))
      described_class.open("http://example.com/image.jpg", "Foo" => "Bar")
    end if RUBY_VERSION >= "2.7"

    it "accepts open-uri options with extension" do
      expect_any_instance_of(URI::HTTP).to receive(:open)
        .with({ "Foo" => "Bar" })
        .and_yield(File.open(image_path, "rb"))
      described_class.open("http://example.com/image.jpg", ".jpg", "Foo" => "Bar")
    end if RUBY_VERSION >= "2.7"

    it "strips out colons from URL" do
      expect_any_instance_of(URI::HTTP).to receive(:open).and_yield(File.open(image_path, "rb"))
      image = described_class.open("http://example.com/image.jpg:large")
      expect(File.extname(image.path)).to eq ".jpg"
    end

    it "does not mistake a path with a colon for a URI schema" do
      expect { described_class.open(image_path(:colon)) }
        .not_to raise_error
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
      expect(File.exist?(image.path)).to eq true
    end

    context "when a tmpdir is configured" do
      before { FileUtils.mkdir_p(new_tmp_dir) }
      after { FileUtils.rm_rf(new_tmp_dir) }

      let(:new_tmp_dir) { File.join(Dir.tmpdir, "new_tmp_dir") }

      it "uses the tmpdir to create the file" do
        allow(MiniMagick).to receive(:tmpdir).and_return(new_tmp_dir)
        image = create
        expect(File.dirname(image.path)).to eq new_tmp_dir
      end
    end
  end

  describe "#initialize" do
    it "initializes a new image" do
      image = described_class.new(image_path)
      expect(image).to be_valid
    end

    it "accepts a Pathname" do
      image = described_class.new(Pathname(image_path))
      expect(image.path).to be_a(String)
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
    end unless Gem::Version.new(MiniMagick.cli_version) >= Gem::Version.new("7.1.1-35")

    it "generates the same hash code for an instance of the same image" do
      expect(image.hash).to eq(same_image.hash)
    end

    it "generates different same hash codes for a different image" do
      expect(image.hash).not_to eq(other_image.hash)
    end unless Gem::Version.new(MiniMagick.cli_version) >= Gem::Version.new("7.1.1-35")
  end

  describe "#tempfile" do
    it "returns the underlying temporary file" do
      image = described_class.open(image_path)

      expect(image.tempfile).to be_a(Tempfile)
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
      expect(File.exist?(subject.path)).to eq true
    end

    it "accepts a block of additional commands" do
      expect {
        subject.format("png") do |b|
          b.resize("100x100!")
        end
      }.to change { subject.dimensions }.to [100, 100]
    end

    it "works without an extension with .open" do
      subject = described_class.open(image_path(:jpg_without_extension))
      subject.format("png")

      expect(File.extname(subject.path)).to eq ".png"
      expect(subject.type).to eq "PNG"
    end

    it "works without an extension with .new" do
      subject = described_class.new(image_path(:jpg_without_extension))
      subject.format("png")

      expect(File.extname(subject.path)).to eq ".png"
      expect(subject.type).to eq "PNG"
    end

    it "deletes the previous tempfile" do
      old_path = subject.path.dup
      subject.format('png')
      expect(File.exist?(old_path)).to eq false
    end

    it "deletes *.cache files generated from .mpc" do
      image = described_class.open(image_path)
      image.format("mpc")
      cache_path = image.path.sub(/mpc$/, "cache")
      image.format("png")

      expect(File.exist?(cache_path)).to eq false
    end

    it "doesn't delete itself when formatted to the same format" do
      subject.format(subject.type.downcase)
      expect(File.exist?(subject.path)).to eq true
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

    it "reformats a layer" do
      subject = described_class.open(image_path(:animation))
      layer = subject.layers.first
      layer.format('jpg')
      expect(layer).to be_valid
      expect(layer.path[/\..+$/]).to eq ".jpg"
      expect(File.exist?(layer.path)).to eq true
    end

    it "clears the info only at the end" do
      subject.format('png') { subject.type }
      expect(subject.type).to eq "PNG"
    end

    it "returns self" do
      expect(subject.format('png')).to eq subject
    end

    it "reads read_opts from passed arguments" do
      subject = described_class.open(image_path(:animation))
      layer = subject.layers.first
      layer.format('jpg', nil, {density: '300'})
      expect(layer).to be_valid
    end

    it "not change tempfile when convert failed" do
      subject = described_class.create(nil) { |f| f.write(File.binread(image_path(:not))) }
      current_path = subject.path
      new_tempfile = MiniMagick::Utilities.tempfile('png')
      new_path = new_tempfile.path
      allow(MiniMagick::Utilities).to receive(:tempfile).and_return(new_tempfile)
      expect { begin; subject.format('png'); rescue; end }.not_to change(subject, :tempfile)
      expect(File.exist?(current_path)).to eq true
      expect(File.exist?(new_path)).to eq false
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

    it "works when writing to the same path" do
      subject.write(subject.path)
      expect(File.read(subject.path)).not_to be_empty
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
      expect(subject[:width]).to be_a(Integer)
      expect(subject[:height]).to be_a(Integer)
      expect(subject[:dimensions]).to all(be_a(Integer))
      expect(subject[:colorspace]).to be_a(String)
      expect(subject[:format]).to match(/[A-Z]/)
      expect(subject[:signature]).to match(/[[:alnum:]]{64}/)
    end

    it "supports string keys" do
      expect(subject["width"]).to be_a(Integer)
      expect(subject["height"]).to be_a(Integer)
      expect(subject["dimensions"]).to all(be_a(Integer))
      expect(subject["colorspace"]).to be_a(String)
      expect(subject["format"]).to match(/[A-Z]/)
      expect(subject['signature']).to match(/[[:alnum:]]{64}/)
    end

    it "reads exif" do
      subject = described_class.new(image_path(:exif))
      expect(subject["EXIF:Flash"]).to eq "0"
    end

    it "passes unknown values directly to -format" do
      expect(subject["%w %h"].split.map(&:to_i)).to eq [subject[:width], subject[:height]]
    end
  end

  it "has attributes" do
    expect(subject.type).to match(/^[A-Z]+$/)
    expect(subject.width).to be_a(Integer).and be_nonzero
    expect(subject.height).to be_a(Integer).and be_nonzero
    expect(subject.dimensions).to all(be_a(Integer))
    expect(subject.size).to be_a(Integer).and be_nonzero
    expect(subject.human_size).to be_a(String).and be_nonempty
    expect(subject.colorspace).to be_a(String)
    expect(subject.resolution).to all(be_a(Integer))
    expect(subject.signature).to match(/[[:alnum:]]{64}/)
  end

  it "generates attributes of layers" do
    expect(subject.layers[0].type).to match(/^[A-Z]+$/)
    expect(subject.layers[0].size).to be > 0
  end

  it "changes colorspace when called with an argument" do
    expect_any_instance_of(MiniMagick::Tool).to receive(:call)
    subject.colorspace("Gray")
  end

  it "changes size when called with an argument" do
    expect_any_instance_of(MiniMagick::Tool).to receive(:call)
    subject.size("20x20")
  end

  describe "#size" do
    it "returns the correct value even if the log contains unit prefixes" do
      subject = described_class.new(image_path(:large_webp))
      expect(subject.size).to be_a(Integer)
    end
  end

  describe "#exif" do
    it "returns a hash of EXIF data" do
      subject = described_class.new(image_path(:exif))
      expect(subject.exif["DateTimeOriginal"]).to be_a(String)
    end

    it "decodes the ExifVersion" do
      subject = described_class.new(image_path(:exif))
      expect(subject.exif["ExifVersion"]).to eq("0220")
    end unless ENV["CI"]

    it "handles no EXIF data" do
      subject = described_class.new(image_path(:no_exif))
      expect(subject.exif).to eq({})
    end
  end

  describe "#resolution" do
    it "accepts units" do
      expect(subject.resolution("PixelsPerCentimeter"))
        .not_to eq subject.resolution("PixelsPerInch")
    end
  end

  describe "#data" do
    describe "when the data return is not an array" do
      subject { described_class.new(image_path(:jpg)) }

      it "returns image JSON data" do
        expect(subject.data["format"]).to eq "JPEG"
        expect(subject.data["colorspace"]).to eq "sRGB"
      end
    end

    describe "when the data return is an array (ex png)" do
      subject { described_class.new(image_path(:png)) }

      it "returns image JSON data" do
        expect(subject.data["format"]).to eq "PNG"
        expect(subject.data["colorspace"]).to eq "sRGB"
      end
    end
  end unless ENV["CI"] # problems installing newer ImageMagick versions on CI

  describe "#layers" do
    it "returns a list of images" do
      expect(subject.layers).to all(be_a(MiniMagick::Image))
      expect(subject.layers.first).to be_valid
    end

    it "returns multiple images for GIFs, PDFs and PSDs" do
      gif = described_class.new(image_path(:gif))

      expect(gif.layers.count).to be > 1
      expect(gif.frames.count).to be > 1
      expect(gif.pages.count).to be > 1
    end

    it "returns one image for other formats" do
      jpg = described_class.new(image_path(:jpg))

      expect(jpg.layers.count).to eq 1
    end
  end

  describe "#get_pixels" do
    let(:magenta) { [255,   0, 255] }
    let(:gray)    { [128, 128, 128] }
    let(:green)   { [  0, 255,   0] }
    let(:cyan)    { [  0, 255, 255] }
    let(:pix)     { subject.get_pixels }

    subject { described_class.open(image_path(:rgb)) }

    context "without modifications" do
      it "returns a width-by-height matrix" do
        pix.each do |row|
          expect(row.length).to eq(subject.width)
        end
      end

      it("returns a magenta pixel") { expect(pix[3][3]  ).to eq(magenta) }
      it("returns a gray pixel")    { expect(pix[-4][-4]).to eq(gray)    }
      it("returns a green pixel")   { expect(pix[3][-4] ).to eq(green)   }
      it("returns a cyan pixel")    { expect(pix[-4][3] ).to eq(cyan)    }
    end

    context "after cropping" do
      let(:cols)    { 10 }
      let(:rows)    {  6 }

      before { subject.crop "#{cols}x#{rows}+3+3" }

      it "returns a matrix of the requested height" do
        expect(pix.length).to eq(rows)
      end

      it "returns a matrix of the requested width" do
        pix.each do |x|
          expect(x.length).to eq(cols)
        end
      end

      it("returns a magenta pixel") { expect(pix[0][0]  ).to eq(magenta)}
      it("returns a gray pixel")    { expect(pix[-1][-1]).to eq(gray)   }
      it("returns a cyan pixel")    { expect(pix[-1][0] ).to eq(cyan)   }
      it("returns a green pixel")   { expect(pix[0][-1] ).to eq(green)  }
    end

    context "after resizing and desaturating" do
      let(:cols) { 8 }
      let(:rows) { 6 }

      before {
        subject.resize "50%"
        subject.colorspace "Gray"
      }

      it "returns a matrix of the requested height" do
        expect(pix.length).to eq(rows)
      end

      it "returns a matrix of the requested width" do
        pix.each do |x|
          expect(x.length).to eq(cols)
        end
      end

      it "returns gray pixels" do
        pix.each do |row|
          row.each do |px|
            expect(px[0]).to eq px[1]
            expect(px[0]).to eq px[2]
          end
        end
      end
    end

    context "when first or last byte could be interpreted as control characters" do
      subject { described_class.open(image_path(:get_pixels)) }

      it "returns a matrix where all pixel has 3 values" do
        pix.each do |row|
          row.each do |px|
            expect(px.length).to eq(3)
          end
        end
      end
    end
  end

  context "missing methods" do
    it "is executed by #method_missing" do
      expect { subject.resize '20x30!' }
        .to change { subject.dimensions }.to [20, 30]
    end

    it "returns self" do
      expect(subject.resize('20x30!')).to eq subject
    end

    it "doesn't let ruby call #to_ary when flattening" do
      [subject, subject].flatten(1)
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
        .to raise_error(MiniMagick::Error, "you must call #format on a MiniMagick::Image directly")
    end

    it "clears the info only at the end" do
      subject.combine_options { |c| c.resize('20x30!'); subject.width }
      expect(subject.dimensions).to eq [20, 30]
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
        .to yield_with_args(an_instance_of(MiniMagick::Tool))
    end

    it "makes the composited image with the provided extension" do
      result = subject.composite(other_image, 'png')
      expect(result.path).to end_with ".png"
    end

    it "defaults the extension to the extension of the base image" do
      subject = described_class.open(image_path(:jpg))
      result = subject.composite(other_image)
      expect(result.path).to end_with ".jpeg"

      subject = described_class.open(image_path(:gif))
      result = subject.composite(other_image)
      expect(result.path).to end_with ".gif"
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

  describe "#destroy!" do
    it "deletes the underlying tempfile" do
      image = described_class.open(image_path)
      image.destroy!

      expect(File.exist?(image.path)).to eq false
    end

    it "doesn't delete when there is no tempfile" do
      image = described_class.new(image_path)
      image.destroy!

      expect(File.exist?(image.path)).to eq true
    end

    it "deletes .cache files generated by handling .mpc files" do
      image = described_class.open(image_path)
      image.format("mpc")
      image.destroy!

      expect(File.exist?(image.path.sub(/mpc$/, "cache"))).to eq false
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

  describe "#landscape?" do
    it "returns true if image width greater than height" do
      image = described_class.open(image_path(:clipping_path))
      expect(image.landscape?).to eql true
    end

    it "returns false if image width less than height" do
      image = described_class.open(image_path(:default))
      expect(image.landscape?).to eql false
    end
  end

  describe "#portrait?" do
    it "returns true if image width greater than height" do
      image = described_class.open(image_path(:default))
      expect(image.portrait?).to eql true
    end

    it "returns false if image width less than height" do
      image = described_class.open(image_path(:clipping_path))
      expect(image.portrait?).to eql false
    end
  end
end
