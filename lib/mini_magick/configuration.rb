require 'mini_magick/utilities'

module MiniMagick
  module Configuration

    # @!macro [attach] thread_attr_accessor
    #   @attribute [rw] $1
    def self.thread_attr_accessor(name)
      define_method(name) do
        Thread.current[:"minimagick_#{name}"]
      end

      define_method("#{name}=") do |value|
        Thread.current[:"minimagick_#{name}"] = value
      end
    end

    ##
    # Set whether you want to use [ImageMagick](http://www.imagemagick.org) or
    # [GraphicsMagick](http://www.graphicsmagick.org).
    #
    # @return [Symbol] `:imagemagick` or `:graphicsmagick`
    #
    thread_attr_accessor :cli
    # @private (for backwards compatibility)
    thread_attr_accessor :processor

    ##
    # If you don't have the CLI tools in your PATH, you can set the path to the
    # executables.
    #
    # @return [String]
    #
    thread_attr_accessor :cli_path
    # @private (for backwards compatibility)
    thread_attr_accessor :processor_path

    ##
    # If you don't want commands to take too long, you can set a timeout (in
    # seconds).
    #
    # @return [Integer]
    #
    thread_attr_accessor :timeout
    ##
    # When set to `true`, it outputs each command to STDOUT in their shell
    # version.
    #
    # @return [Boolean]
    #
    thread_attr_accessor :debug
    ##
    # Logger for {#debug}, default is `MiniMagick::Logger.new($stdout)`, but
    # you can override it, for example if you want the logs to be written to
    # a file.
    #
    # @return [Logger]
    #
    thread_attr_accessor :logger

    ##
    # If set to `true`, it will `identify` every newly created image, and raise
    # `MiniMagick::Invalid` if the image is not valid. Useful for validating
    # user input, although it adds a bit of overhead. Defaults to `true`.
    #
    # @return [Boolean]
    #
    thread_attr_accessor :validate_on_create
    ##
    # If set to `true`, it will `identify` every image that gets written (with
    # {MiniMagick::Image#write}), and raise `MiniMagick::Invalid` if the image
    # is not valid. Useful for validating that processing was sucessful,
    # although it adds a bit of overhead. Defaults to `true`.
    #
    # @return [Boolean]
    #
    thread_attr_accessor :validate_on_write

    ##
    # If set to `false`, it will not raise errors when ImageMagick returns
    # status code different than 0. Defaults to `true`.
    #
    # @return [Boolean]
    #
    thread_attr_accessor :whiny

    ##
    # Instructs MiniMagick how to execute the shell commands. Available
    # APIs are "open3" (default) and "posix-spawn" (requires the "posix-spawn"
    # gem).
    #
    # @return [String]
    #
    thread_attr_accessor :shell_api

    def self.extended(base)
      base.validate_on_create = true
      base.validate_on_write = true
      base.whiny = true
      base.shell_api = "open3"
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

    # @private
    def processor
      Thread.current[:minimagick_processor] ||= ["mogrify", "gm"].detect do |processor|
        MiniMagick::Utilities.which(processor)
      end
    end

    # @private
    def processor=(processor)
      Thread.current[:minimagick_processor] = processor.to_s

      unless ["mogrify", "gm"].include?(processor.to_s)
        raise ArgumentError,
          "processor has to be set to either \"mogrify\" or \"gm\"" \
          ", was set to #{processor.inspect}"
      end
    end

    # @private
    def cli
      Thread.current[:minimagick_cli] ||
        case processor.to_s
        when "mogrify" then :imagemagick
        when "gm"      then :graphicsmagick
        else
          raise MiniMagick::Error, "ImageMagick/GraphicsMagick is not installed"
        end
    end

    # @private
    def cli=(value)
      Thread.current[:minimagick_cli] = value

      if not [:imagemagick, :graphicsmagick].include?(value)
        raise ArgumentError,
          "CLI has to be set to either :imagemagick or :graphicsmagick" \
          ", was set to #{value.inspect}"
      end
    end

    # @private
    def cli_path
      Thread.current[:minimagick_cli_path] || Thread.current[:minimagick_processor_path]
    end

    # @private
    def logger
      Thread.current[:minimagick_logger] || MiniMagick::Logger.new($stdout)
    end

    # For backwards compatibility.
    #
    # @private
    def reload_tools
      warn "[MiniMagick] MiniMagick.reload_tools is deprecated because it is no longer necessary"
    end

  end
end
