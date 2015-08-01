require "mini_magick/logger"
require "timeout"

module MiniMagick
  ##
  # Sends commands to the shell (more precisely, it sends commands directly to
  # the operating system).
  #
  # @private
  #
  class Shell

    def run(command, options = {})
      stdout, stderr, code = execute(command)

      case code
      when 1
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with error:\n#{stderr}"
      when 127
        fail MiniMagick::Error, stderr
      end if options.fetch(:whiny, true)

      $stderr.print(stderr) unless options[:stderr] == false

      stdout
    end

    def execute(command)
      stdout, stderr, status =
        MiniMagick.logger.debug(command.join(" ")) do
          Timeout.timeout(MiniMagick.timeout) do
            send("execute_#{MiniMagick.shell_api.gsub("-", "_")}", *command)
          end
        end

      [stdout, stderr, status.exitstatus]
    rescue Errno::ENOENT, IOError
      ["", "executable not found: \"#{command.first}\"", 127]
    end

    def execute_open3(*command)
      require "open3"
      Open3.capture3(*command)
    end

    def execute_posix_spawn(*command)
      require "posix-spawn"
      pid, stdin, stdout, stderr = POSIX::Spawn.popen4(*command)
      Process.waitpid(pid)

      [stdout.read, stderr.read, $?]
    end

  end
end
