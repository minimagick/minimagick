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

      case status
      when 1
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with error:\n#{stderr}"
      when 127
        fail MiniMagick::Error, stderr
      end if options.fetch(:whiny, MiniMagick.whiny)

      $stderr.print(stderr) unless options[:stderr] == false

      [stdout, stderr, status]
    end

    def execute(command, options = {})
      stdout, stderr, status =
        log(command.join(" ")) do
          Timeout.timeout(MiniMagick.timeout) do
            send("execute_#{MiniMagick.shell_api.gsub("-", "_")}", command, options)
          end
        end

      [stdout, stderr, status.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    private

    def execute_open3(command, options = {})
      require "open3"

      Open3.capture3(*command, binmode: true, stdin_data: options[:stdin].to_s)
    end

    def execute_posix_spawn(command, options = {})
      require "posix-spawn"

      pid, stdin, stdout, stderr = POSIX::Spawn.popen4(*command)
      [stdin, stdout, stderr].each(&:binmode)
      stdin.write(options[:stdin].to_s)
      Process.waitpid(pid)

      [stdout.read, stderr.read, $?]
    end

    def log(command, &block)
      value = nil
      duration = Benchmark.realtime { value = block.call }
      MiniMagick.logger.debug "[%.2fs] %s" % [duration, command]
      value
    end

  end
end
