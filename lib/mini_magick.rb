require 'mini_magick/configuration'
require 'mini_magick/tool'
require 'mini_magick/image'

module MiniMagick

  extend MiniMagick::Configuration

  ##
  # Checks whether the CLI used is ImageMagick.
  #
  # @return [Boolean]
  def self.imagemagick?
    cli == :imagemagick
  end

  ##
  # Checks whether the CLI used is GraphicsMagick.
  #
  # @return [Boolean]
  def self.graphicsmagick?
    cli == :graphicsmagick
  end

  ##
  # Returns ImageMagick's/GraphicsMagick's version.
  #
  # @return [String]
  def self.cli_version
    output = MiniMagick::Tool::Identify.new(&:version)
    output[/\d+\.\d+\.\d+(-\d+)?/]
  end

  class Error < RuntimeError; end
  class Invalid < StandardError; end

end
