require 'mini_magick/utilities'
require 'logger'

module MiniMagick
  module Configuration

    ##
    # Set whether you want to use [ImageMagick](http://www.imagemagick.org) or
    # [GraphicsMagick](http://www.graphicsmagick.org).
    #
    # @return [Symbol] `:imagemagick` or `:graphicsmagick`
    #
    attr_accessor :cli
    # @private (for backwards compatibility)
    attr_accessor :processor

    ##
    # If you don't have the CLI tools in your PATH, you can set the path to the
    # executables.
    #
    # @return [String]
    #
    attr_accessor :cli_path
    # @private (for backwards compatibility)
    attr_accessor :processor_path

    ##
    # If you don't want commands to take too long, you can set a timeout (in
    # seconds).
    #
    # @return [Integer]
    #
    attr_accessor :timeout
    ##
    # When set to `true`, it outputs each command to STDOUT in their shell
    # version.
    #
    # @return [Boolean]
    #
    attr_accessor :debug
    ##
    # Logger for {#debug}, default is `MiniMagick::Logger.new(STDOUT)`, but
    # you can override it, for example if you want the logs to be written to
    # a file.
    #
    # @return [Logger]
    #
    attr_accessor :logger

    ##
    # If set to `true`, it will `identify` every newly created image, and raise
    # `MiniMagick::Invalid` if the image is not valid. Useful for validating
    # user input, although it adds a bit of overhead. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :validate_on_create
    ##
    # If set to `true`, it will `identify` every image that gets written (with
    # {MiniMagick::Image#write}), and raise `MiniMagick::Invalid` if the image
    # is not valid. Useful for validating that processing was sucessful,
    # although it adds a bit of overhead. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :validate_on_write

    ##
    # If set to `false`, it will not raise errors when ImageMagick returns
    # status code different than 0. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :whiny

    ##
    # Instructs MiniMagick how to execute the shell commands. Available
    # APIs are "open3" (default) and "posix-spawn" (requires the "posix-spawn"
    # gem).
    #
    # @return [String]
    #
    attr_accessor :shell_api

    def self.extended(base)
      base.validate_on_create = true
      base.validate_on_write = true
      base.whiny = true
      base.shell_api = "open3"
      base.logger = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
    end

    ##
    # @yield [self]
    # @example
    #   MiniMagick.configure do |config|
    #     config.cli = :graphicsmagick
    #     config.timeout = 5
    #   end
    #
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
        else
          raise MiniMagick::Error, "ImageMagick/GraphicsMagick is not installed"
        end
    end

    def cli=(value)
      @cli = value

      if not [:imagemagick, :graphicsmagick].include?(@cli)
        raise ArgumentError,
          "CLI has to be set to either :imagemagick or :graphicsmagick" \
          ", was set to #{@cli.inspect}"
      end
    end

    def cli_path
      @cli_path || @processor_path
    end

    def debug=(value)
      warn "MiniMagick.debug is deprecated and will be removed in MiniMagick 5. Use `MiniMagick.logger.level = Logger::DEBUG` instead."
      logger.level = value ? Logger::DEBUG : Logger::INFO
    end

    # Backwards compatibility
    def reload_tools
      warn "MiniMagick.reload_tools is deprecated because it is no longer necessary"
    end

  end
end
