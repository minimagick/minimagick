require "spec_helper"

RSpec.describe MiniMagick::Shell do
  subject { described_class.new }

  describe "#run" do
    it "calls #execute with the command" do
      expect(subject).to receive(:execute).and_call_original
      subject.run(%W[identify #{image_path}])
    end

    it "returns stdout" do
      allow(subject).to receive(:execute).and_return(["stdout", "stderr", 0])
      output = subject.run(%W[foo])
      expect(output).to eq "stdout"
    end

    it "uses stderr for error messages" do
      allow(subject).to receive(:execute).and_return(["", "stderr", 1])
      expect { subject.run(%W[foo]) }
        .to raise_error(MiniMagick::Error, /`foo`.*stderr/m)
    end

    it "raises an error when executable wasn't found" do
      allow(subject).to receive(:execute).and_return(["", "not found", 127])
      expect { subject.run(%W[foo]) }
        .to raise_error(MiniMagick::Error, /not found/)
    end

    it "raises errors only in whiny mode" do
      subject = described_class.new(false)
      allow(subject).to receive(:execute).and_return(["stdout", "", 127])
      expect(subject.run(%W[foo])).to eq "stdout"
    end

    it "prints to stderr output to $stderr in non-whiny mode" do
      subject = described_class.new(false)
      allow(subject).to receive(:execute).and_return(["", "stderr", 1])
      expect { subject.run(%W[foo]) }.to output("stderr").to_stderr
    end
  end

  describe "#execute" do
    it "executes the command in the shell" do
      stdout, * = subject.execute(%W[identify #{image_path(:gif)}])
      expect(stdout).to match("GIF")
    end

    it "logs the command and execution time in debug mode" do
      allow(MiniMagick).to receive(:debug).and_return(true)
      expect { subject.execute(%W[identify #{image_path(:gif)}]) }.
        to output(/\[\d+.\d+s\] identify #{image_path(:gif)}/).to_stdout
    end

    it "returns an appropriate response when command wasn't found" do
      stdout, stderr, code = subject.execute(%W[unexisting command])
      expect(code).to eq 127
      expect(stderr).to match(/not found/)
    end

    it "doesn't break on spaces" do
      stdout, * = subject.execute(["identify", "-format", "%w %h", image_path])
      expect(stdout).to match(/\d+ \d+/)
    end
  end
end
