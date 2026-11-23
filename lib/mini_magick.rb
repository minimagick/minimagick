require 'mini_magick/version'
require 'mini_magick/configuration'
require 'mini_magick/utilities'
require 'mini_magick/tool'
require 'mini_magick/image'

module MiniMagick

  # Raised when an ImageMagick command exits with a nonzero exit status (unless
  # errors are disabled), or when the executable cannot be found.
  Error = Class.new(RuntimeError)
  # Raised when an image is invalid or its data can't be read.
  Invalid = Class.new(StandardError)
  # Raised when an ImageMagick command exceeds the configured timeout.
  TimeoutError = Class.new(Error)

  extend MiniMagick::Configuration

  ##
  # Checks whether ImageMagick 7 is installed.
  #
  # @return [Boolean]
  def self.imagemagick7?
    return false if graphicsmagick
    return @imagemagick7 if defined?(@imagemagick7)
    @imagemagick7 = !!MiniMagick::Utilities.which("magick")
  end

  ##
  # @!method self.animate(**options, &block)
  # @!method self.compare(**options, &block)
  # @!method self.composite(**options, &block)
  # @!method self.conjure(**options, &block)
  # @!method self.convert(**options, &block)
  #   On ImageMagick 7 this executes `magick`, on ImageMagick 6 `convert`.
  # @!method self.display(**options, &block)
  # @!method self.identify(**options, &block)
  # @!method self.import(**options, &block)
  # @!method self.mogrify(**options, &block)
  # @!method self.montage(**options, &block)
  # @!method self.stream(**options, &block)
  #
  # Creates a {MiniMagick::Tool} for the corresponding ImageMagick tool. When
  # a block is given, the tool is yielded, the command is executed, and its
  # output is returned.
  #
  # @param options [Hash] see {MiniMagick::Tool#initialize}
  # @yield [MiniMagick::Tool]
  # @return [MiniMagick::Tool, String]
  #
  # @example
  #   MiniMagick.convert do |convert|
  #     convert << "input.jpg"
  #     convert.resize "100x100"
  #     convert << "output.jpg"
  #   end
  #
  %w[animate compare composite conjure convert display identify import mogrify montage stream].each do |tool|
    define_singleton_method(tool) do |**options, &block|
      name = imagemagick7? && tool == "convert" ? "magick" : tool
      MiniMagick::Tool.new(name, **options, &block)
    end
  end

  ##
  # Returns ImageMagick version.
  #
  # @example
  #   MiniMagick.cli_version #=> "7.1.1-33"
  #
  # @return [String]
  def self.cli_version
    output = MiniMagick.identify(&:version)
    output[/\d+\.\d+\.\d+(-\d+)?/]
  end
end
