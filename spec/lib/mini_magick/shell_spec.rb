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
      output = subject.run(%W[foo], warnings: false)
      expect(output).to eq ["stdout", "stderr", 0]
    end

    it "uses stderr and status for error messages" do
      allow(subject).to receive(:execute).and_return(["", "stderr", 1])

      expected_msg = "`foo` failed with status: 1 and error:\nstderr"

      expect { subject.run(%W[foo]) }
        .to raise_error(MiniMagick::Error, expected_msg)
    end

    it "raises an error when executable wasn't found" do
      allow(subject).to receive(:execute).and_return(["", "not found", 127])
      expect { subject.run(%W[foo]) }
        .to raise_error(MiniMagick::Error, /not found/)
    end

    it "raises errors only in error mode" do
      allow(subject).to receive(:execute).and_return(["stdout", "", 127])
      expect { subject.run(%W[foo], errors: false) }.not_to raise_error
    end

    it "prints to stderr output to $stderr in non-error mode" do
      allow(subject).to receive(:execute).and_return(["", "stderr", 1])
      expect { subject.run(%W[foo], errors: false) }.to output("stderr").to_stderr
    end

    it "terminate long running commands if timeout is set" do
      expect { subject.run(%W[convert #{image_path} -resize 10000x10000 -blur 0x20 null:], timeout: 1) }
        .to raise_error(MiniMagick::TimeoutError)
    end
  end

  describe "#execute" do
    it "executes the command in the shell" do
      stdout, stderr, status = subject.execute(%W[identify #{image_path(:gif)}])

      expect(stdout).to match("GIF")
      expect(stderr).to eq ""
      expect(status).to eq 0

      stdout, stderr, status = subject.execute(%W[identify foo])

      expect(stdout).to eq ""
      expect(stderr).to match("unable to open image")
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

    it "executes the command with the environment variables from MiniMagick.cli_env" do
      allow(MiniMagick).to receive(:cli_env).and_return({"MY_ENV" => "my value"})

      stdout, * = subject.execute(["echo $MY_ENV"])

      expect(stdout).to match("my value")
    end

    it "does not override the timeout if MAGICK_TIME_LIMIT is set in MiniMagick.cli_env" do
      allow(MiniMagick).to receive(:timeout).and_return(1)
      allow(MiniMagick).to receive(:cli_env).and_return({'MAGICK_TIME_LIMIT' => 'override'})

      stdout, * = subject.execute(["echo $MAGICK_TIME_LIMIT"])

      expect(stdout).to match("1")
    end

    it "allows setting MAGICK_TIME_LIMIT via MiniMagick.cli_env" do
      allow(MiniMagick).to receive(:cli_env).and_return({'MAGICK_TIME_LIMIT' => '1'})

      stdout, * = subject.execute(["echo $MAGICK_TIME_LIMIT"])

      expect(stdout).to match("1")
    end
  end
end
