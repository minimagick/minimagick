require "spec_helper"

RSpec.describe MiniMagick::Shell do
  subject { described_class.new }

  describe "#run" do
    it "calls #execute with the command" do
      expect(subject).to receive(:execute).and_call_original
      subject.run("identify #{image_path}")
    end

    it "returns stdout" do
      allow(subject).to receive(:execute).and_return(["stdout", "stderr", 0])
      output = subject.run("foo")
      expect(output).to eq "stdout"
    end

    it "uses stderr for error messages" do
      expect { subject.run("identify bla") }
        .to raise_error(MiniMagick::Error, /unable to open image `bla'/)
    end

    it "raises an error when executable wasn't found" do
      expect { subject.run("foo") }
        .to raise_error(MiniMagick::Error, /command not found/)
    end
  end

  describe "#execute" do
    it "executes the command in the shell" do
      stdout, * = subject.execute("identify #{image_path(:gif)}")
      expect(stdout).to match("GIF")
    end

    it "timeouts afer a period of time" do
      allow(MiniMagick).to receive(:timeout).and_return(0.001)
      expect { subject.execute("identify") }
        .to raise_error(Timeout::Error)
    end

    it "logs the command and execution time in debug mode" do
      allow(MiniMagick).to receive(:debug).and_return(true)
      expect { subject.execute("identify #{image_path(:gif)}") }.
        to output(/\[\d+.\d+s\] identify #{image_path(:gif)}/).to_stdout
    end

    it "raises errors only in whiny mode" do
      subject = described_class.new(false)
      stdout, * = subject.execute("identify -list Command")
      expect(stdout).to match("-list")
    end
  end
end
