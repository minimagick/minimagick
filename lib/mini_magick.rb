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
  class << self
    attr_accessor :processor
    attr_accessor :processor_path
    attr_accessor :timeout

    def choose_processor
      if MiniMagick::Utilities.which('mogrify').size > 0
        self.processor = 'mogrify'
      elsif MiniMagick::Utilities.which('gm').size > 0
        self.processor = "gm"
      end
    end

    def image_magick_version
      @@version ||= Gem::Version.create(`mogrify --version`.split(" ")[2].split("-").first)
    end

    def minimum_image_magick_version
      @@minimum_version ||= Gem::Version.create("6.6.3")
    end

    def valid_version_installed?
      image_magick_version >= minimum_image_magick_version
    end

    # Picks the right processor if it isn't set and tells if it's mogrify
    def mogrify?
      self.choose_processor if self.processor.nil?

      self.processor == 'mogrify'
    end

    # Picks the right processor if it isn't set and tells if it's gm
    def gm?
      self.choose_processor if self.processor.nil?

      self.processor == 'gm'
    end
  end
end
