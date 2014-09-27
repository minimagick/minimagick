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
      subject << "foo" << "bar"
      expect(subject.args).to eq %W[foo bar]
    end
  end

  describe "#+" do
    it "switches the last option to + form" do
      subject.help.+
      subject.debug.+ 8
      expect(subject.args).to eq %W[+help +debug 8]
    end
  end

  it "adds dynamically generated operator methods" do
    subject.regard_warnings.list("Command")
    expect(subject.args).to eq %W[-regard-warnings -list Command]
  end

  it "doesn't just delegate to #method_missing" do
    expect(subject.class.instance_methods).to include(:help)
  end

  it "adds dynamically generated creation operator methods" do
    subject.radial_gradient.canvas "khaki"
    expect(subject.args).to eq %W[radial-gradient: canvas:khaki]
  end

  it "resets the dynamically generated operator methods on CLI change" do
    MiniMagick.cli = :imagemagick
    expect(subject).to respond_to(:quiet)

    MiniMagick.cli = :graphicsmagick
    expect(subject).not_to respond_to(:quiet)
    expect(subject).to respond_to(:ping)
  end
end
