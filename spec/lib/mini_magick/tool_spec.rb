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

    it "accepts a block, and yields stdin, stdout and exit status" do
      allow_any_instance_of(MiniMagick::Shell).to receive(:execute).and_return(["stdout", "stderr", 0])
      expect { |block| subject.call(&block) }.to yield_with_args("stdout", "stderr", 0)
      expect(subject.call{}).to eq "stdout"
    end

    it "accepts stdin" do
      subject.stdin
      output = subject.call(stdin: File.read(image_path))
      expect(output).to match(/JPEG/)
    end
  end

  describe ".new" do
    it "accepts a block, and immediately executes the command" do
      output = described_class.new("identify") do |builder|
        builder << image_path(:gif)
      end
      expect(output).to match("GIF")
    end

    it "defaults whiny to MiniMagick.whiny" do
      allow(MiniMagick).to receive(:whiny).and_return(false)
      expect(subject.instance_variable_get("@whiny")).to eq false
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

  describe "#clone" do
    it "adds an option instead of the default behaviour" do
      subject.clone
      expect(subject.args).to eq %W[-clone]
    end

    it "accepts arguments" do
      subject.clone(0)
      expect(subject.args).to eq %W[-clone 0]
    end

    it "is convertable to plus version" do
      subject.clone.+
      expect(subject.args).to eq %W[+clone]
    end
  end

  describe "#method_missing" do
    it "adds CLI options" do
      subject.foo_bar('baz')
      expect(subject.args).to eq %w[-foo-bar baz]
    end
  end

  it "defines creation operator methods" do
    subject.radial_gradient.canvas "khaki"
    expect(subject.args).to eq %W[radial-gradient: canvas:khaki]
  end

  it "doesn't raise errors when false is passed to the constructor" do
    subject.help
    subject.call(false)

    MiniMagick::Tool::Identify.new(false, &:help)
  end
end
