require 'mini_magick/utilities'

module MiniMagick
  module Configuration

    attr_accessor :cli, :processor
    attr_accessor :cli_path, :processor_path
    attr_accessor :timeout
    attr_accessor :debug
    attr_accessor :logger
    attr_accessor :validate_on_create
    attr_accessor :validate_on_write

    def self.extended(base)
      base.validate_on_create = true
      base.validate_on_write = true
    end

    def configure
      yield self
    end

    def processor
      @processor ||= ["mogrify", "gm"].detect do |processor|
        MiniMagick::Utilities.which(processor)
      end
    end

    def processor=(processor)
      @processor = processor.to_s

      unless ["mogrify", "gm"].include?(@processor)
        raise ArgumentError,
          "processor has to be set to either \"mogrify\" or \"gm\"" \
          ", was set to #{@processor.inspect}"
      end
    end

    def cli
      @cli ||
        case processor.to_s
        when "mogrify" then :imagemagick
        when "gm"      then :graphicsmagick
        end
    end

    def cli=(value)
      @cli = value

      unless [:imagemagick, :graphicsmagick].include?(@cli)
        raise ArgumentError,
          "CLI has to be set to either :imagemagick or :graphicsmagick" \
          ", was set to #{@cli.inspect}"
      end
    end

    def cli_path
      @cli_path || @processor_path
    end

    def logger
      @logger || MiniMagick::Logger.new($stdout)
    end

  end
end
