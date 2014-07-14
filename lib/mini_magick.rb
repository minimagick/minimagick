require 'tempfile'
require 'subexec'
require 'stringio'
require 'pathname'
require 'shellwords'
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
    attr_accessor :validate_on_create
    attr_accessor :validate_on_write

    ##
    # Tries to detect the current processor based if any of the processors exist.
    # Mogrify have precedence over gm by default.
    #
    # === Returns
    # * [String] The detected procesor
    def choose_processor
      self.processor = if MiniMagick::Utilities.which('mogrify')
                         :mogrify
                       elsif MiniMagick::Utilities.which('gm')
                         :gm
                       else
                         nil
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
    # Picks the right processor if it isn't set and returns whether it's mogrify or not.
    #
    # === Returns
    # * [Boolean]
    def mogrify?
      choose_processor if processor.nil?

      return processor.to_s.downcase.to_sym == :mogrify unless processor.nil?
      false
    end

    ##
    # Picks the right processor if it isn't set and returns whether it's graphicsmagick or not.
    #
    # === Returns
    # * [Boolean]
    def gm?
      choose_processor if processor.nil?

      return processor.to_s.downcase.to_sym == :gm unless processor.nil?
      false
    end
  end
end
