require "mini_magick/shell"

module MiniMagick
  class Tool

    autoload :Animate,   "mini_magick/tool/animate"
    autoload :Compare,   "mini_magick/tool/compare"
    autoload :Composite, "mini_magick/tool/composite"
    autoload :Conjure,   "mini_magick/tool/conjure"
    autoload :Convert,   "mini_magick/tool/convert"
    autoload :Display,   "mini_magick/tool/display"
    autoload :Identify,  "mini_magick/tool/identify"
    autoload :Import,    "mini_magick/tool/import"
    autoload :Mogrify,   "mini_magick/tool/mogrify"
    autoload :Montage,   "mini_magick/tool/montage"
    autoload :Stream,    "mini_magick/tool/stream"

    IMAGE_CREATION_OPERATORS = %w[
      xc canvas logo rose gradient radial-gradient
      plasma tile pattern label caption text
    ]

    attr_reader :name, :args

    def self.new(*args)
      instance = super(*args)

      if block_given?
        yield instance
        instance.call
      else
        instance
      end
    end

    def initialize(name)
      @name = name
      @args = []
    end

    def call(whiny = true)
      shell = MiniMagick::Shell.new(whiny)
      shell.run(command).strip
    end

    def command
      [executable, *args].join(" ")
    end

    def executable
      result = name
      result = "gm #{result}" if MiniMagick.graphicsmagick?
      result = File.join(MiniMagick.cli_path, result) if MiniMagick.cli_path
      result
    end

    def <<(*args)
      self.args.concat args
      self
    end

    def +(value = nil)
      args.last.sub!('-', '+')
      args << value.to_s.inspect if value
    end

    def self.inherited(child)
      child.class_eval do
        # Create methods based on creation operators' name.
        #
        #   mogrify = MiniMagick::Tool.new("mogrify")
        #   mogrify.canvas("khaki")
        #   mogrify.command #=> "mogrify canvas:khaki"
        #
        IMAGE_CREATION_OPERATORS.each do |operator|
          operator_name = operator.gsub('-', '_')
          define_method(operator_name) do |value = nil|
            args << [operator, value].join(':')
            self
          end
        end

        # Parse the help page for that specific ImageMagick tool, extract all
        # the options, and make methods from them.
        #
        #  mogrify = MiniMagick::Tool.new("mogrify")
        #  mogrify.antialias
        #  mogrify.depth(8)
        #  mogrify.resize("500x500")
        #  mogirfy.command #=> "mogrify -antialias -depth "8" -resize "500x500""
        #
        name = self.name.split("::").last.downcase
        help = (MiniMagick::Tool.new(name) << "-help").call(false)
        options = help.scan(/^\s*-(?:[a-z]|-)+/).map(&:strip)
        options.each do |option|
          option_name = option[1..-1].gsub('-', '_')
          define_method(option_name) do |value = nil|
            args << option
            args << value.to_s.inspect if value
            self
          end
        end
      end
    end

  end
end
