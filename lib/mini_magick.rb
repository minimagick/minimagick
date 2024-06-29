require 'mini_magick/version'
require 'mini_magick/configuration'
require 'mini_magick/utilities'

module MiniMagick

  extend MiniMagick::Configuration

  ##
  # Checks whether ImageMagick 7 is installed.
  #
  # @return [Boolean]
  def self.imagemagick7?
    return @imagemagick7 if defined?(@imagemagick7)
    @imagemagick7 = !!MiniMagick::Utilities.which("magick")
  end

  ##
  # Returns ImageMagick version.
  #
  # @return [String]
  def self.cli_version
    output = MiniMagick::Tool::Identify.new(&:version)
    output[/\d+\.\d+\.\d+(-\d+)?/]
  end

  class Error < RuntimeError; end
  class Invalid < StandardError; end

end

require 'mini_magick/tool'
require 'mini_magick/image'
