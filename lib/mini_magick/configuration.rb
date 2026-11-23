require 'mini_magick/utilities'
require 'logger'

module MiniMagick
  module Configuration

    ##
    # Uses [GraphicsMagick](http://www.graphicsmagick.org/) instead of
    # ImageMagick, by prefixing commands with `gm` instead of `magick`.
    # GraphicsMagick isn't officially supported, so some features (e.g.
    # {MiniMagick::Image#data} and {MiniMagick::Image#exif}) won't work.
    # Defaults to `false`.
    #
    # @return [Boolean]
    attr_accessor :graphicsmagick

    ##
    # Adds a prefix to the CLI command.
    # For example, you could use `firejail` to run all commands in a sandbox.
    # Can be a string, or an array of strings.
    # e.g. 'firejail', or ['firejail', '--force']
    #
    # @example
    #   MiniMagick.cli_prefix = ["firejail", "--force"]
    #   MiniMagick.identify.command #=> ["firejail", "--force", "magick", "identify"]
    #
    # @return [String]
    # @return [Array<String>]
    #
    attr_accessor :cli_prefix

    ##
    # Adds environment variables to every CLI command call.
    # For example, you could use it to set `LD_PRELOAD="/path/to/libsomething.so"`.
    # Must be a hash of strings keyed to valid environment variable name strings.
    # e.g. {'MY_ENV' => 'my value'}
    #
    # This is also useful for setting ImageMagick's resource limits, such as
    # `MAGICK_MEMORY_LIMIT`. Defaults to `{}`.
    #
    # @return [Hash]
    #
    attr_accessor :cli_env

    ##
    # If set to `true`, commands will only have access to environment
    # variables defined in {#cli_env}, plus `HOME`, `PATH` and `LANG` from the
    # current environment, since those are required for running commands. It
    # will not pass on any other environment variables from the system.
    # Defaults to `false`.
    #
    # @return [Boolean]
    #
    attr_accessor :restricted_env

    ##
    # If you don't want commands to take too long, you can set a timeout (in
    # seconds). This sets ImageMagick's `MAGICK_TIME_LIMIT` environment
    # variable (overriding the one in {#cli_env}), and also terminates the
    # command once the timeout has elapsed, raising {MiniMagick::TimeoutError}.
    # Defaults to `nil` (no timeout).
    #
    # @return [Integer, nil]
    #
    attr_accessor :timeout

    ##
    # Logger for commands, default is `Logger.new($stdout)` with `INFO` level,
    # but you can override it, for example if you want the logs to be written
    # to a file. Commands and their execution times are logged with `DEBUG`
    # level.
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
    # If set to `false`, it will not raise errors when ImageMagick returns
    # status code different than 0. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :errors

    ##
    # If set to `false`, it will not forward warnings from ImageMagick to
    # standard error. Defaults to `true`.
    #
    # @return [Boolean]
    #
    attr_accessor :warnings

    def self.extended(base)
      base.tmpdir = Dir.tmpdir
      base.errors = true
      base.logger = Logger.new($stdout).tap { |l| l.level = Logger::INFO }
      base.warnings = true
      base.cli_env = {}.freeze
      base.restricted_env = false
      base.graphicsmagick = false
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
  end
end
