require 'mini_magick/utilities'
require 'logger'

module MiniMagick
  module Configuration

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
    #     config.timeout = 5
    #   end
    #
    def configure
      yield self
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
