require "spec_helper"

RSpec.describe MiniMagick::Shell do
  subject { described_class.new }

  describe "#run" do
    it "calls #execute with the command" do
      expect(subject).to receive(:execute).and_call_original
      subject.run(%W[identify #{image_path}])
    end

    it "returns stdout, stderr and status" do
      allow(subject).to receive(:execute).and_return(["stdout", "stderr", 0])
      output = subject.run(%W[foo])
      expect(output).to eq ["stdout", "stderr", 0]
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
      allow(subject).to receive(:execute).and_return(["stdout", "", 127])
      expect { subject.run(%W[foo], whiny: false) }.not_to raise_error
    end

    it "prints to stderr output to $stderr in non-whiny mode" do
      allow(subject).to receive(:execute).and_return(["", "stderr", 1])
      expect { subject.run(%W[foo], whiny: false) }.to output("stderr").to_stderr
    end
  end

  describe "#execute" do
    SHELL_APIS.each do |shell_api|
      context "with #{shell_api}", shell_api: shell_api do
        it "executes the command in the shell" do
          stdout, stderr, status = subject.execute(%W[identify #{image_path(:gif)}])

          expect(stdout).to match("GIF")
          expect(stderr).to eq ""
          expect(status).to eq 0

          stdout, stderr, status = subject.execute(%W[identify foo])

          expect(stdout).to eq ""
          expect(stderr).to match("unable to open image `foo'")
          expect(status).to eq 1
        end

        it "returns an appropriate response when command wasn't found" do
          stdout, stderr, code = subject.execute(%W[unexisting command])
          expect(code).to eq 127
        end

        it "logs the command and execution time in debug mode" do
          MiniMagick.logger = Logger.new(stream = StringIO.new)
          MiniMagick.logger.level = Logger::DEBUG
          subject.execute(%W[identify #{image_path(:gif)}])
          stream.rewind
          expect(stream.read).to match /\[\d+.\d+s\] identify #{image_path(:gif)}/
        end

        it "doesn't break on spaces" do
          stdout, * = subject.execute(["identify", "-format", "%w %h", image_path])
          expect(stdout).to match(/\d+ \d+/)
        end
      end
    end
  end
end
