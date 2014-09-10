require 'mini_magick/command_builder'
require 'mini_magick/errors'
require 'mini_magick/image'
require 'mini_magick/utilities'

module MiniMagick
  @validate_on_create = true
  @validate_on_write = true

  class << self
    attr_accessor :processor
    attr_accessor :processor_path
    attr_accessor :timeout
    attr_accessor :debug
    attr_accessor :validate_on_create
    attr_accessor :validate_on_write

    ##
    # Tries to detect the current processor based if any of the processors exist.
    # Mogrify have precedence over gm by default.
    #
    # === Returns
    # * [Symbol] The detected procesor
    def processor
      @processor ||= [:mogrify, :gm].detect do |processor|
        MiniMagick::Utilities.which(processor.to_s)
      end
    end

    ##
    # Discovers the imagemagick version based on mogrify's output.
    #
    # === Returns
    # * The imagemagick version
    def image_magick_version
      @@version ||= Gem::Version.create(`mogrify --version`.split(' ')[2].split('-').first)
    end

    ##
    # The minimum allowed imagemagick version
    #
    # === Returns
    # * The minimum imagemagick version
    def minimum_image_magick_version
      @@minimum_version ||= Gem::Version.create('6.6.3')
    end

    ##
    # Checks whether the imagemagick's version is valid
    #
    # === Returns
    # * [Boolean]
    def valid_version_installed?
      image_magick_version >= minimum_image_magick_version
    end

    ##
    # Checks whether the current processory is mogrify.
    #
    # === Returns
    # * [Boolean]
    def mogrify?
      processor && processor.to_sym == :mogrify
    end

    ##
    # Checks whether the current processor is graphicsmagick.
    #
    # === Returns
    # * [Boolean]
    def gm?
      processor && processor.to_sym == :gm
    end
  end
end
