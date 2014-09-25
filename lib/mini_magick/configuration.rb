require 'mini_magick/utilities'

module MiniMagick
  module Configuration

    attr_accessor :cli, (:processor)
    attr_accessor :cli_path, (:processor_path)
    attr_accessor :timeout
    attr_accessor :debug
    attr_accessor :validate_on_create
    attr_accessor :validate_on_write

    def self.extended(base)
      base.validate_on_create = true
      base.validate_on_write = true
    end

    def configure
      yield self
    end

    def processor
      @processor ||= ["mogrify", "gm"].detect do |processor|
        MiniMagick::Utilities.which(processor)
      end
    end

    def cli
      @cli ||=
        case processor.to_s
        when "mogrify" then :imagemagick
        when "gm"      then :graphicsmagick
        end
    end

  end
end
