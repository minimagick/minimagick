require "mini_magick/logger"

require "open3"
require "timeout"

module MiniMagick
  ##
  # Sends commands to the shell (more precisely, it sends commands directly to
  # the operating system).
  #
  # @private
  #
  class Shell

    def initialize(whiny = true)
      @whiny = whiny
    end

    def run(command)
      stdout, stderr, code = execute(command)

      case code
      when 1
        fail MiniMagick::Error, "`#{command.join(" ")}` failed with error:\n#{stderr}"
      when 127
        fail MiniMagick::Error, stderr
      end if @whiny

      stdout
    end

    def execute(command)
      stdout, stderr, status =
        MiniMagick.logger.debug(command.join(" ")) do
          Timeout.timeout(MiniMagick.timeout) do
            Open3.capture3(command.shelljoin)
          end
        end

      [stdout, stderr, status.exitstatus]
    rescue Errno::ENOENT
      ["", "executable not found: \"#{command.first}\"", 127]
    end

  end
end
