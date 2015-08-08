require "spec_helper"

RSpec.describe MiniMagick::Tool do
  subject { MiniMagick::Tool::Identify.new }

  describe "#call" do
    it "calls the shell to run the command" do
      subject << image_path(:gif)
      output = subject.call
      expect(output).to match("GIF")
    end

    it "strips the output" do
      subject << image_path
      output = subject.call
      expect(output).not_to end_with("\n")
    end
  end

  describe ".new" do
    it "accepts a block, and immediately executes the command" do
      output = described_class.new("identify") do |builder|
        builder << image_path(:gif)
      end
      expect(output).to match("GIF")
    end
  end

  describe "#command" do
    it "includes the executable and the arguments" do
      allow(subject).to receive(:args).and_return(%W[-list Command])
      expect(subject.command).to include(*%W[identify -list Command])
    end
  end

  describe "#executable" do
    it "prepends 'gm' to the command list when using GraphicsMagick" do
      allow(MiniMagick).to receive(:cli).and_return(:graphicsmagick)
      expect(subject.executable).to eq %W[gm identify]
    end

    it "respects #cli_path" do
      allow(MiniMagick).to receive(:cli).and_return(:imagemagick)
      allow(MiniMagick).to receive(:cli_path).and_return("path/to/cli")
      expect(subject.executable).to eq %W[path/to/cli/identify]
    end
  end

  describe "#<<" do
    it "adds argument to the args list" do
      subject << "foo" << "bar" << 123
      expect(subject.args).to eq %W[foo bar 123]
    end
  end

  describe "#merge!" do
    it "adds arguments to the args list" do
      subject << "pre-existing"
      subject.merge! ["foo", 123]
      expect(subject.args).to eq %W[pre-existing foo 123]
    end
  end

  describe "#+" do
    it "switches the last option to + form" do
      subject.help
      subject.help.+
      subject.debug.+ "foo"
      subject.debug.+ 8, "bar"
      expect(subject.args).to eq %W[-help +help +debug foo +debug 8 bar]
    end
  end

  describe "#stack" do
    it "it surrounds added arguments with parantheses" do
      subject.stack do |stack|
        stack << "foo"
        stack << "bar"
      end
      expect(subject.args).to eq %W[( foo bar )]
    end
  end

  ["ImageMagick", "GraphicsMagick"].each do |cli|
    context "with #{cli}", cli: cli.downcase.to_sym do
      it "adds dynamically generated operator methods" do
        subject.help.depth(8)
        expect(subject.args).to eq %W[-help -depth 8]
      end

      it "doesn't just delegate to #method_missing" do
        expect(subject.class.instance_methods).to include(:help)
      end

      it "adds dynamically generated creation operator methods" do
        subject.radial_gradient.canvas "khaki"
        expect(subject.args).to eq %W[radial-gradient: canvas:khaki]
      end
    end
  end

  it "resets the dynamically generated operator methods on CLI change" do
    MiniMagick.cli = :imagemagick
    expect(subject).to respond_to(:quiet)

    MiniMagick.cli = :graphicsmagick
    expect(subject).not_to respond_to(:quiet)
    expect(subject).to respond_to(:ping)
  end

  # https://github.com/minimagick/minimagick/issues/264
  it "adds the #gravity method to GraphicsMagick's mogrify" do
    MiniMagick.with_cli :graphicsmagick do
      expect(MiniMagick::Tool::Mogrify.new).to respond_to(:gravity)
    end
  end

  it "doesn't raise errors when false is passed to the constructor" do
    subject.help
    subject.call(false)

    MiniMagick::Tool::Identify.new(false, &:help)
  end
end
