require "timeout"
require "benchmark"

module MiniMagick
  ##
  # Sends commands to the shell (more precisely, it sends commands directly to
  # the operating system).
  #
  # @private
  #
  class Shell

    def run(command, stdin: nil, errors: MiniMagick.errors, warnings: MiniMagick.warnings)
      stdout, stderr, status = execute(command, stdin: stdin)

      if status != 0 && errors
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with status: #{status.inspect} and error:\n#{stderr}"
      end

      $stderr.print(stderr) if warnings && stderr.strip != %(WARNING: The convert command is deprecated in IMv7, use "magick")

      [stdout, stderr, status]
    end

    def execute(command, options = {})
      stdout, stderr, status = log(command.join(" ")) do
        execute_open3(command, options)
      end

      [stdout, stderr, status&.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    private

    def execute_open3(command, options = {})
      require "open3"

      # We would ideally use Open3.capture3, but it wouldn't allow us to
      # terminate the command after timing out.
      Open3.popen3(*command) do |in_w, out_r, err_r, thread|
        [in_w, out_r, err_r].each(&:binmode)
        stdout_reader = Thread.new { out_r.read }
        stderr_reader = Thread.new { err_r.read }
        begin
          in_w.write options[:stdin].to_s
        rescue Errno::EPIPE
        end
        in_w.close

        unless thread.join(MiniMagick.timeout)
          Process.kill("TERM", thread.pid) rescue nil
          Process.waitpid(thread.pid)      rescue nil
          raise Timeout::Error, "MiniMagick command timed out: #{command}"
        end

        [stdout_reader.value, stderr_reader.value, thread.value]
      end
    end

    def log(command, &block)
      value = nil
      duration = Benchmark.realtime { value = block.call }
      MiniMagick.logger.debug "[%.2fs] %s" % [duration, command]
      value
    end

  end
end
