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

    def self.inherited(child)
      child_name = child.name.split("::").last.downcase
      child.send :include, Operators.for(child_name)
    end

    def self.new(*args)
      instance = super(*args)

      if block_given?
        yield instance
        instance.call
      else
        instance
      end
    end

    attr_reader :name, :args

    def initialize(name)
      @name = name
      @args = []
    end

    def call(whiny = true)
      shell = MiniMagick::Shell.new(whiny)
      shell.run(command).strip
    end

    def command
      [*executable, *args]
    end

    def executable
      exe = [name]
      exe.unshift "gm" if MiniMagick.graphicsmagick?
      exe.unshift File.join(MiniMagick.cli_path, exe.shift) if MiniMagick.cli_path
      exe
    end

    def <<(*args)
      self.args.concat args
      self
    end

    def +(value = nil)
      args.last.sub!(/^-/, '+')
      args << value.to_s if value
    end

    private

    class Operators
      IMAGE_CREATION_OPERATORS = %w[
        xc canvas logo rose gradient radial-gradient
        plasma tile pattern label caption text
      ]

      def self.for(tool_name)
        mod = Module.new
        mod.module_eval(%Q{
          def self.to_s
            "#{self.name}(#{tool_name})"
          end

          def self.inspect
            "#{self.name}(#{tool_name})"
          end
        })

        mod.module_eval do
          # Create methods based on creation operators' name.
          #
          #   mogrify = MiniMagick::Tool.new("mogrify")
          #   mogrify.canvas("khaki")
          #   mogrify.command.join(" ") #=> "mogrify canvas:khaki"
          #
          IMAGE_CREATION_OPERATORS.each do |operator|
            define_method(operator.gsub('-', '_')) do |value = nil|
              args << [operator, value].join(':')
              self
            end
          end
        end

        mod.module_eval do
          # Parse the help page for that specific ImageMagick tool, extract all
          # the options, and make methods from them.
          #
          #  mogrify = MiniMagick::Tool.new("mogrify")
          #  mogrify.antialias
          #  mogrify.depth(8)
          #  mogrify.resize("500x500")
          #  mogirfy.command.join(" ") #=> "mogrify -antialias -depth "8" -resize "500x500""
          #
          help = (MiniMagick::Tool.new(tool_name) << "-help").call(false)
          options = help.scan(/^\s*-(?:[a-z]|-)+/).map(&:strip)
          options.each do |option|
            define_method(option[1..-1].gsub('-', '_')) do |value = nil|
              args << option
              args << value.to_s if value
              self
            end
          end
        end

        mod
      end
    end
    private_constant :Operators

  end
end
