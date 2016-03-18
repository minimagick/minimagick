require "mini_magick/shell"

module MiniMagick
  ##
  # Abstract class that wraps command-line tools. It shouldn't be used directly,
  # but through one of its subclasses (e.g. {MiniMagick::Tool::Mogrify}). Use
  # this class if you want to be closer to the metal and execute ImageMagick
  # commands directly, but still with a nice Ruby interface.
  #
  # @example
  #   MiniMagick::Tool::Mogrify.new do |builder|
  #     builder.resize "500x500"
  #     builder << "path/to/image.jpg"
  #   end
  #
  class Tool

    CREATION_OPERATORS = %w[
      xc canvas logo rose gradient radial-gradient plasma pattern label caption
      text
    ]

    ##
    # Aside from classic instantiation, it also accepts a block, and then
    # executes the command in the end.
    #
    # @example
    #   version = MiniMagick::Tool::Identify.new { |b| b.version }
    #   puts version
    #
    # @return [MiniMagick::Tool, String] If no block is given, returns an
    #   instance of the tool, if block is given, returns the output of the
    #   command.
    #
    def self.new(*args)
      instance = super(*args)

      if block_given?
        yield instance
        instance.call
      else
        instance
      end
    end

    # @private
    attr_reader :name, :args

    # @param whiny [Boolean] Whether to raise errors on exit codes different
    #   than 0.
    # @example
    #   MiniMagick::Tool::Identify.new(false) do |identify|
    #     identify.help # returns exit status 1, which would otherwise throw an error
    #   end
    def initialize(name, whiny = MiniMagick.whiny)
      @name  = name
      @whiny = whiny
      @args  = []
    end

    ##
    # Executes the command that has been built up.
    #
    # @example
    #   mogrify = MiniMagick::Tool::Mogrify.new
    #   mogrify.resize("500x500")
    #   mogrify << "path/to/image.jpg"
    #   mogrify.call # executes `mogrify -resize 500x500 path/to/image.jpg`
    #
    # @param whiny [Boolean] Whether you want an error to be raised when
    #   ImageMagick returns an exit code of 1. You may want this because
    #   some ImageMagick's commands (`identify -help`) return exit code 1,
    #   even though no error happened.
    #
    # @return [Array] Output and Errors of command
    #
    def call(whiny = @whiny, options = {})
      shell = MiniMagick::Shell.new
      shell.run(command, options.merge(whiny: whiny)).map(&:strip)
    end

    ##
    # The currently built-up command.
    #
    # @return [Array<String>]
    #
    # @example
    #   mogrify = MiniMagick::Tool::Mogrify.new
    #   mogrify.resize "500x500"
    #   mogrify.contrast
    #   mogrify.command #=> ["mogrify", "-resize", "500x500", "-contrast"]
    #
    def command
      [*executable, *args]
    end

    ##
    # The executable used for this tool. Respects
    # {MiniMagick::Configuration#cli} and {MiniMagick::Configuration#cli_path}.
    #
    # @return [Array<String>]
    #
    # @example
    #   MiniMagick.configure { |config| config.cli = :graphicsmagick }
    #   identify = MiniMagick::Tool::Identify.new
    #   identify.executable #=> ["gm", "identify"]
    #
    def executable
      exe = [name]
      exe.unshift "gm" if MiniMagick.graphicsmagick?
      exe.unshift File.join(MiniMagick.cli_path, exe.shift) if MiniMagick.cli_path
      exe
    end

    ##
    # Appends raw options, useful for appending image paths.
    #
    # @return [self]
    #
    def <<(arg)
      args << arg.to_s
      self
    end

    ##
    # Merges a list of raw options.
    #
    # @return [self]
    #
    def merge!(new_args)
      new_args.each { |arg| self << arg }
      self
    end

    ##
    # Changes the last operator to its "plus" form.
    #
    # @example
    #   MiniMagick::Tool::Mogrify.new do |mogrify|
    #     mogrify.antialias.+
    #     mogrify.distort.+("Perspective", "0,0,4,5 89,0,45,46")
    #   end
    #   # executes `mogrify +antialias +distort Perspective '0,0,4,5 89,0,45,46'`
    #
    # @return [self]
    #
    def +(*values)
      args[-1] = args[-1].sub(/^-/, '+')
      self.merge!(values)
      self
    end

    ##
    # Create an ImageMagick stack in the command (surround.
    #
    # @example
    #   MiniMagick::Tool::Convert.new do |convert|
    #     convert << "wand.gif"
    #     convert.stack do |stack|
    #       stack << "wand.gif"
    #       stack.rotate(30)
    #     end
    #     convert.append.+
    #     convert << "images.gif"
    #   end
    #   # executes `convert wand.gif \( wizard.gif -rotate 30 \) +append images.gif`
    #
    def stack
      self << "("
      yield self
      self << ")"
    end

    ##
    # Define creator operator methods
    #
    #   mogrify = MiniMagick::Tool.new("mogrify")
    #   mogrify.canvas("khaki")
    #   mogrify.command.join(" ") #=> "mogrify canvas:khaki"
    #
    CREATION_OPERATORS.each do |operator|
      define_method(operator.gsub('-', '_')) do |value = nil|
        self << "#{operator}:#{value}"
        self
      end
    end

    ##
    # This option is a valid ImageMagick option, but it's also a Ruby method,
    # so we need to override it so that it correctly acts as an option method.
    #
    def clone(*args)
      self << '-clone'
      self.merge!(args)
      self
    end

    ##
    # Any undefined method will be transformed into a CLI option
    #
    #   mogrify = MiniMagick::Tool.new("mogrify")
    #   mogrify.adaptive_blur("...")
    #   mogrify.foo_bar
    #   mogrify.command.join(" ") "mogrify -adaptive-blur ... -foo-bar"
    #
    def method_missing(name, *args)
      option = "-#{name.to_s.tr('_', '-')}"
      self << option
      self.merge!(args)
      self
    end

    def respond_to_missing?(method_name, include_private = false)
      true
    end

    def self.option_methods
      @option_methods ||= (
        tool = new
        tool << "-help"
        help_page = tool.call(false, stderr: false)

        cli_options = help_page.first.scan(/^\s+-[a-z\-]+/).map(&:strip)
        if tool.name == "mogrify" && MiniMagick.graphicsmagick?
          # These options were undocumented before 2015-06-14 (see gm bug 302)
          cli_options |= %w[-box -convolve -gravity -linewidth -mattecolor -render -shave]
        end

        cli_options.map { |o| o[1..-1].tr('-','_') }
      )
    end

  end
end

require "mini_magick/tool/animate"
require "mini_magick/tool/compare"
require "mini_magick/tool/composite"
require "mini_magick/tool/conjure"
require "mini_magick/tool/convert"
require "mini_magick/tool/display"
require "mini_magick/tool/identify"
require "mini_magick/tool/import"
require "mini_magick/tool/mogrify"
require "mini_magick/tool/montage"
require "mini_magick/tool/stream"
