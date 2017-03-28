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

    def run(command, options = {})
      stdout, stderr, status = execute(command, stdin: options[:stdin])

      if status != 0 && options.fetch(:whiny, MiniMagick.whiny)
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with error:\n#{stderr}"
      end

      $stderr.print(stderr) unless options[:stderr] == false

      [stdout, stderr, status]
    end

    def execute(command, options = {})
      stdout, stderr, status =
        log(command.join(" ")) do
          send("execute_#{MiniMagick.shell_api.gsub("-", "_")}", command, options)
        end

      [stdout, stderr, status.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    private

    def execute_open3(command, options = {})
      require "open3"

      in_w, out_r, err_r, subprocess_thread = Open3.popen3(*command)

      capture_command(in_w, out_r, err_r, subprocess_thread, options)
    end

    def execute_posix_spawn(command, options = {})
      require "posix-spawn"

      pid, in_w, out_r, err_r = POSIX::Spawn.popen4(*command)
      subprocess_thread = Process.detach(pid)

      capture_command(in_w, out_r, err_r, subprocess_thread, options)
    end

    def capture_command(in_w, out_r, err_r, subprocess_thread, options)
      [in_w, out_r, err_r].each(&:binmode)
      stdout_reader = Thread.new { out_r.read }
      stderr_reader = Thread.new { err_r.read }
      begin
        in_w.write options[:stdin].to_s
      rescue Errno::EPIPE
      end
      in_w.close

      Timeout.timeout(MiniMagick.timeout) { subprocess_thread.join }

      [stdout_reader.value, stderr_reader.value, subprocess_thread.value]
    rescue Timeout::Error => error
      Process.kill("TERM", subprocess_thread.pid)
      raise error
    ensure
      [out_r, err_r].each(&:close)
    end

    def log(command, &block)
      value = nil
      duration = Benchmark.realtime { value = block.call }
      MiniMagick.logger.debug "[%.2fs] %s" % [duration, command]
      value
    end

  end
end
