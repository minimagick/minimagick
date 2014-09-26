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
      expect(subject.command).to eq %W[identify -list Command]
    end
  end

  describe "#executable" do
    it "prepends 'gm' to the command list when using GraphicsMagick" do
      allow(MiniMagick).to receive(:cli).and_return(:graphicsmagick)
      expect(subject.executable).to eq %W[gm identify]
    end

    it "respects #cli_path" do
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

  describe "normal operator" do
    it "adds the operator to arguments" do
      subject.regard_warnings
      expect(subject.args).to eq %W[-regard-warnings]
    end

    it "adds the optional value" do
      subject.list("Command")
      expect(subject.args).to eq %W[-list Command]
    end

    it "accepts numbers" do
      subject.depth(8)
      expect(subject.args).to eq %W[-depth 8]
    end
  end

  describe "#+" do
    it "switches the last option to + form" do
      subject.list
      subject.+
      expect(subject.args).to eq %W[+list]
    end

    it "adds the optional value" do
      subject.list
      subject.+ "Command"
      expect(subject.args).to eq %W[+list Command]
    end

    it "accepts numbers" do
      subject.depth
      subject.+ 8
      expect(subject.args).to eq %W[+depth 8]
    end
  end

  describe "creation operator" do
    it "is added with or without arguments" do
      subject.rose.canvas "khaki"
      expect(subject.args).to eq %W[rose: canvas:khaki]
    end

    it "is added with dashes" do
      subject.radial_gradient
      expect(subject.args).to eq %W[radial-gradient:]
    end
  end
end
