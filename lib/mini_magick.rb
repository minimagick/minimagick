require 'tempfile'
require 'subexec'
require 'stringio'
require 'pathname'
require 'shellwords'
require 'mini_magick/command_builder'
require 'mini_magick/errors'
require 'mini_magick/image'

module MiniMagick
  class << self
    attr_accessor :processor
    attr_accessor :processor_path
    attr_accessor :timeout

    # Experimental method for automatically selecting a processor
    # such as gm. Only works on *nix.
    #
    # TODO: Write tests for this and figure out what platforms it supports
    def choose_processor
      if `which mogrify`.size > 0
        return
      elsif `which gm`.size > 0
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
  end
end
