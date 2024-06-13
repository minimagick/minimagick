require 'mini_magick/utilities'
require 'logger'

module MiniMagick
  module Configuration

    ##
    # If you don't have the CLI tools in your PATH, you can set the path to the
    # executables.
    #
    attr_accessor :cli_path

    ##
    # Adds a prefix to the CLI command.
    # For example, you could use `firejail` to run all commands in a sandbox.
    # Can be a string, or an array of strings.
    # e.g. 'firejail', or ['firejail', '--force']
    #
    # @return [String]
    # @return [Array<String>]
    #
    attr_accessor :cli_prefix

    ##
    # If you don't want commands to take too long, you can set a timeout (in
    # seconds).
    #
    # @return [Integer]
    #
    attr_accessor :timeout
    ##
    # Logger for commands, default is `Logger.new($stdout)`, but you can
    # override it, for example if you want the logs to be written to a file.
    #
    # @return [Logger]
    #
    attr_accessor :logger
    ##
    # Temporary directory used by MiniMagick, default is `Dir.tmpdir`, but
    # you can override it.
    #
    # @return [String]
    #
    attr_accessor :tmpdir

    ##
    # If set to `true`, it will `identify` every newly created image, and raise
    # `MiniMagick::Invalid` if the image is not valid. Useful for validating
    # user input, although it adds a bit of overhead. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :validate_on_create

    ##
    # If set to `false`, it will not raise errors when ImageMagick returns
    # status code different than 0. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :whiny

    ##
    # If set to `false`, it will not forward warnings from ImageMagick to
    # standard error.
    attr_accessor :warnings

    def self.extended(base)
      base.tmpdir = Dir.tmpdir
      base.validate_on_create = true
      base.whiny = true
      base.logger = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
      base.warnings = true
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

    CLI_DETECTION = {
      imagemagick7:   "magick",
      imagemagick:    "mogrify",
      graphicsmagick: "gm",
    }

    # @private (for backwards compatibility)
    def processor
      @processor ||= CLI_DETECTION.values.detect do |processor|
        MiniMagick::Utilities.which(processor)
      end
    end

    # @private (for backwards compatibility)
    def processor=(processor)
      @processor = processor.to_s

      unless CLI_DETECTION.value?(@processor)
        raise ArgumentError,
          "processor has to be set to either \"magick\", \"mogrify\" or \"gm\"" \
          ", was set to #{@processor.inspect}"
      end
    end

    ##
    # Get [ImageMagick](http://www.imagemagick.org) or
    # [GraphicsMagick](http://www.graphicsmagick.org).
    #
    # @return [Symbol] `:imagemagick` or `:graphicsmagick`
    #
    def cli
      if instance_variable_defined?("@cli")
        instance_variable_get("@cli")
      else
        cli = CLI_DETECTION.key(processor) or
          fail MiniMagick::Error, "You must have ImageMagick or GraphicsMagick installed"

        instance_variable_set("@cli", cli)
      end
    end

    ##
    # Set whether you want to use [ImageMagick](http://www.imagemagick.org) or
    # [GraphicsMagick](http://www.graphicsmagick.org).
    #
    def cli=(value)
      @cli = value

      if not CLI_DETECTION.key?(@cli)
        raise ArgumentError,
          "CLI has to be set to either :imagemagick, :imagemagick7 or :graphicsmagick" \
          ", was set to #{@cli.inspect}"
      end
    end

    def shell_api=(value)
      warn "MiniMagick.shell_api is deprecated and will be removed in MiniMagick 5. The posix-spawn gem doesn't improve performance recent Ruby versions anymore, so support for it will be removed."
      @shell_api = value
    end

    def shell_api
      @shell_api || "open3"
    end
  end
end
