require "benchmark"

module MiniMagick
  ##
  # Responsible for logging commands to stdout (activated when
  # `MiniMagick.debug` is set to `true`). Implements a simplified Logger
  # interface.
  #
  # @private
  #
  class Logger

    attr_accessor :format

    def initialize(io)
      @io     = io
      @format = "[%<duration>.2fs] %<command>s"
    end

    def debug(command, &action)
      benchmark(action) do |duration|
        output(duration: duration, command: command) if MiniMagick.debug
      end
    end

    def output(data)
      printf @io, "#{format}\n", data
    end

    def benchmark(action)
      return_value = nil
      duration = Benchmark.realtime { return_value = action.call }
      yield duration
      return_value
    end

  end
end
