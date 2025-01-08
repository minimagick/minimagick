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

    it "sets MAGICK_TIME_LIMIT to MiniMagick.timeout or the given timeout" do
      allow(MiniMagick).to receive(:timeout).and_return(123)

      stdout, stderr, status = subject.execute(%W[env])

      expect(stdout).to match("MAGICK_TIME_LIMIT=123")
      expect(stderr).to eq ""
      expect(status).to eq 0

      stdout, stderr, status = subject.execute(%W[env], timeout: 456)

      expect(stdout).to match("MAGICK_TIME_LIMIT=456")
      expect(stderr).to eq ""
      expect(status).to eq 0
    end

    it "executes the command with the environment variables from MiniMagick.cli_env set in the shell" do
      allow(MiniMagick).to receive(:cli_env).and_return({'MY_ENV' => 'my value'})

      stdout, stderr, status = subject.execute(%W[env])

      expect(stdout).to match("MY_ENV=my value")
      expect(stderr).to eq ""
      expect(status).to eq 0
    end

    it "does not override the timeout if MAGICK_TIME_LIMIT is set in MiniMagick.cli_env" do
      allow(MiniMagick).to receive(:cli_env).and_return({'MAGICK_TIME_LIMIT' => 'override'})

      stdout, stderr, status = subject.execute(%W[env], timeout: 1)

      expect(stdout).to match("MAGICK_TIME_LIMIT=1")
      expect(stderr).to eq ""
      expect(status).to eq 0
    end
  end
end
