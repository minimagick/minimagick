require "open3"

module MiniMagick
  ##
  # Sends commands to the shell (more precisely, it sends commands directly to
  # the operating system).
  #
  # @private
  #
  class Shell

    def run(command, errors: MiniMagick.errors, warnings: MiniMagick.warnings, **options)
      stdout, stderr, status = execute(command, **options)

      if status != 0
        if stderr.include?("time limit exceeded")
          fail MiniMagick::TimeoutError, "`#{command.join(" ")}` has timed out"
        elsif errors
          fail MiniMagick::Error, "`#{command.join(" ")}` failed with status: #{status.inspect} and error:\n#{stderr}"
        end
      end

      $stderr.print(stderr) if warnings

      [stdout, stderr, status]
    end

    def execute(command, stdin: "", timeout: MiniMagick.timeout)
      env = MiniMagick.restricted_env ? ENV.to_h.slice("HOME", "PATH", "LANG") : {} # Using #to_h for Ruby 2.5 compatibility.
      env.merge!(MiniMagick.cli_env)
      env["MAGICK_TIME_LIMIT"] = timeout.to_s if timeout

      stdout, stderr, status = log(command.join(" ")) do
        # We would ideally use Open3.capture3, but it doesn't allow us to
        # terminate the command after timing out. We can't rely solely on
        # ImageMagick's own $MAGICK_TIME_LIMIT for this, because it's only
        # checked periodically inside ImageMagick's processing loops, so it
        # can fire too late (or not at all) depending on the operation.
        Open3.popen3(env, *command, unsetenv_others: MiniMagick.restricted_env) do |stdin_io, stdout_io, stderr_io, wait_thread|
          stdin_io.binmode
          stdout_io.binmode
          stderr_io.binmode

          stdout_reader = Thread.new { stdout_io.read }
          stderr_reader = Thread.new { stderr_io.read }

          begin
            # Matches how Open3.capture3 detects IO objects.
            if stdin.respond_to?(:readpartial)
              IO.copy_stream(stdin, stdin_io)
            else
              stdin_io.write(stdin)
            end
          rescue Errno::EPIPE
          end
          stdin_io.close

          if timeout && !wait_thread.join(timeout)
            Process.kill("TERM", wait_thread.pid) rescue nil
            wait_thread.join
            fail MiniMagick::TimeoutError, "`#{command.join(" ")}` has timed out"
          end

          [stdout_reader.value, stderr_reader.value, wait_thread.value]
        end
      end

      [stdout, stderr, status&.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    private

    def log(command, &block)
      time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      value = block.call
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_start
      MiniMagick.logger.debug "[%.2fs] %s" % [duration, command]
      value
    end

  end
end
