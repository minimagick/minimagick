require 'tempfile'
require 'stringio'
require 'pathname'
require 'uri'
require 'open-uri'

require 'mini_magick/image/info'
require 'mini_magick/utilities'

module MiniMagick
  class Image

    ##
    # This is the primary loading method used by all of the other class
    # methods.
    #
    # Use this to pass in a stream object. Must respond to #read(size) or be a
    # binary string object (BLOBBBB)
    #
    # Probably easier to use the {.open} method if you want to open a file or a
    # URL.
    #
    # @param stream [#read, String] Some kind of stream object that needs
    #   to be read or is a binary String blob
    # @param ext [String] A manual extension to use for reading the file. Not
    #   required, but if you are having issues, give this a try.
    # @return [MiniMagick::Image]
    #
    def self.read(stream, ext = nil)
      if stream.is_a?(String)
        stream = StringIO.new(stream)
      end

      create(ext) { |file| IO.copy_stream(stream, file) }
    end

    ##
    # Creates an image object from a binary string blob which contains raw
    # pixel data (i.e. no header data).
    #
    # @param blob [String] Binary string blob containing raw pixel data.
    # @param columns [Integer] Number of columns.
    # @param rows [Integer] Number of rows.
    # @param depth [Integer] Bit depth of the encoded pixel data.
    # @param map [String] A code for the mapping of the pixel data. Example:
    #   'gray' or 'rgb'.
    # @param format [String] The file extension of the image format to be
    #   used when creating the image object.
    # Defaults to 'png'.
    # @return [MiniMagick::Image] The loaded image.
    #
    def self.import_pixels(blob, columns, rows, depth, map, format = 'png')
      # Create an image object with the raw pixel data string:
      create(".dat", false) { |f| f.write(blob) }.tap do |image|
        output_path = image.path.sub(/\.\w+$/, ".#{format}")
        # Use ImageMagick to convert the raw data file to an image file of the
        # desired format:
        MiniMagick::Tool::Convert.new do |convert|
          convert.size "#{columns}x#{rows}"
          convert.depth depth
          convert << "#{map}:#{image.path}"
          convert << output_path
        end

        image.path.replace output_path
      end
    end

    ##
    # Opens a specific image file either on the local file system or at a URI.
    # Use this if you don't want to overwrite the image file.
    #
    # Extension is either guessed from the path or you can specify it as a
    # second parameter.
    #
    # @param path_or_url [String] Either a local file path or a URL that
    #   open-uri can read
    # @param ext [String] Specify the extension you want to read it as
    # @return [MiniMagick::Image] The loaded image
    #
    def self.open(path_or_url, ext = nil)
      ext ||=
        if File.exist?(path_or_url)
          File.extname(path_or_url)
        else
          File.extname(URI(path_or_url).path)
        end

      Kernel.open(path_or_url, "rb") do |file|
        read(file, ext)
      end
    end

    ##
    # Used to create a new Image object data-copy. Not used to "paint" or
    # that kind of thing.
    #
    # Takes an extension in a block and can be used to build a new Image
    # object. Used by both {.open} and {.read} to create a new object. Ensures
    # we have a good tempfile.
    #
    # @param ext [String] Specify the extension you want to read it as
    # @param validate [Boolean] If false, skips validation of the created
    #   image. Defaults to true.
    # @yield [Tempfile] You can #write bits to this object to create the new
    #   Image
    # @return [MiniMagick::Image] The created image
    #
    def self.create(ext = nil, validate = MiniMagick.validate_on_create, &block)
      tempfile = MiniMagick::Utilities.tempfile(ext.to_s.downcase, &block)

      new(tempfile.path, tempfile).tap do |image|
        image.validate! if validate
      end
    end

    ##
    # @private
    # @!macro [attach] attribute
    #   @!attribute [r] $1
    #
    def self.attribute(name, key = name.to_s)
      define_method(name) do |*args|
        if args.any? && MiniMagick::Tool::Mogrify.instance_methods.include?(name)
          mogrify { |b| b.send(name, *args) }
        else
          @info[key, *args]
        end
      end
    end

    ##
    # @return [String] The location of the current working file
    #
    attr_reader :path

    ##
    # Create a new {MiniMagick::Image} object.
    #
    # _DANGER_: The file location passed in here is the *working copy*. That
    # is, it gets *modified*. You can either copy it yourself or use {.open}
    # which creates a temporary file for you and protects your original.
    #
    # @param input_path [String] The location of an image file
    # @yield [MiniMagick::Tool::Mogrify] If block is given, {#combine_options}
    #   is called.
    #
    def initialize(input_path, tempfile = nil, &block)
      @path = input_path
      @tempfile = tempfile
      @info = MiniMagick::Image::Info.new(@path)

      combine_options(&block) if block
    end

    def eql?(other)
      self.class.equal?(other.class) &&
        signature == other.signature
    end
    alias == eql?

    def hash
      signature.hash
    end

    ##
    # Returns raw image data.
    #
    # @return [String] Binary string
    #
    def to_blob
      File.binread(path)
    end

    ##
    # Checks to make sure that MiniMagick can read the file and understand it.
    #
    # This uses the 'identify' command line utility to check the file. If you
    # are having issues with this, then please work directly with the
    # 'identify' command and see if you can figure out what the issue is.
    #
    # @return [Boolean]
    #
    def valid?
      validate!
      true
    rescue MiniMagick::Invalid
      false
    end

    ##
    # Runs `identify` on the current image, and raises an error if it doesn't
    # pass.
    #
    # @raise [MiniMagick::Invalid]
    #
    def validate!
      identify
    rescue MiniMagick::Error => error
      raise MiniMagick::Invalid, error.message
    end

    ##
    # Returns the image format (e.g. "JPEG", "GIF").
    #
    # @return [String]
    #
    attribute :type, "format"
    ##
    # @return [String]
    #
    attribute :mime_type
    ##
    # @return [Integer]
    #
    attribute :width
    ##
    # @return [Integer]
    #
    attribute :height
    ##
    # @return [Array<Integer>]
    #
    attribute :dimensions
    ##
    # Returns the file size of the image (in bytes).
    #
    # @return [Integer]
    #
    attribute :size
    ##
    # Returns the file size in a human readable format.
    #
    # @return [String]
    #
    attribute :human_size
    ##
    # @return [String]
    #
    attribute :colorspace
    ##
    # @return [Hash]
    #
    attribute :exif
    ##
    # Returns the resolution of the photo. You can optionally specify the
    # units measurement.
    #
    # @example
    #   image.resolution("PixelsPerInch") #=> [250, 250]
    # @see http://www.imagemagick.org/script/command-line-options.php#units
    # @return [Array<Integer>]
    #
    attribute :resolution
    ##
    # Returns the message digest of this image as a SHA-256, hexidecimal
    # encoded string. This signature uniquely identifies the image and is
    # convenient for determining if an image has been modified or whether two
    # images are identical.
    #
    # @example
    #   image.signature #=> "60a7848c4ca6e36b8e2c5dea632ecdc29e9637791d2c59ebf7a54c0c6a74ef7e"
    # @see http://www.imagemagick.org/api/signature.php
    # @return [String]
    #
    attribute :signature
    ##
    # Returns the information from `identify -verbose` in a Hash format.
    #
    # @return [Hash]
    attribute :details

    ##
    # Use this method if you want to access raw Identify's format API.
    #
    # @example
    #    image["%w %h"]       #=> "250 450"
    #    image["%r"]          #=> "DirectClass sRGB"
    #
    # @param value [String]
    # @see http://www.imagemagick.org/script/escape.php
    # @return [String]
    #
    def [](value)
      @info[value.to_s]
    end
    alias info []

    ##
    # Returns layers of the image. For example, JPEGs are 1-layered, but
    # formats like PSDs, GIFs and PDFs can have multiple layers/frames/pages.
    #
    # @example
    #   image = MiniMagick::Image.new("document.pdf")
    #   image.pages.each_with_index do |page, idx|
    #     page.write("page#{idx}.pdf")
    #   end
    # @return [Array<MiniMagick::Image>]
    #
    def layers
      layers_count = identify.lines.count
      layers_count.times.map do |idx|
        MiniMagick::Image.new("#{path}[#{idx}]")
      end
    end
    alias pages layers
    alias frames layers

    ##
    # This is used to change the format of the image. That is, from "tiff to
    # jpg" or something like that. Once you run it, the instance is pointing to
    # a new file with a new extension!
    #
    # *DANGER*: This renames the file that the instance is pointing to. So, if
    # you manually opened the file with Image.new(file_path)... Then that file
    # is DELETED! If you used Image.open(file) then you are OK. The original
    # file will still be there. But, any changes to it might not be...
    #
    # Formatting an animation into a non-animated type will result in
    # ImageMagick creating multiple pages (starting with 0).  You can choose
    # which page you want to manipulate.  We default to the first page.
    #
    # If you would like to convert between animated formats, pass nil as your
    # page and ImageMagick will copy all of the pages.
    #
    # @param format [String] The target format... Like 'jpg', 'gif', 'tiff' etc.
    # @param page [Integer] If this is an animated gif, say which 'page' you
    #   want with an integer. Default 0 will convert only the first page; 'nil'
    #   will convert all pages.
    # @yield [MiniMagick::Tool::Convert] It optionally yields the command,
    #   if you want to add something.
    # @return [self]
    #
    def format(format, page = 0)
      @info.clear

      if @tempfile
        new_tempfile = MiniMagick::Utilities.tempfile(".#{format}")
        new_path = new_tempfile.path
      else
        new_path = path.sub(/\.\w+$/, ".#{format}")
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert << (page ? "#{path}[#{page}]" : path)
        yield convert if block_given?
        convert << new_path
      end

      if @tempfile
        @tempfile.unlink
        @tempfile = new_tempfile
      else
        File.delete(path) unless path == new_path
      end

      path.replace new_path

      self
    end

    ##
    # You can use multiple commands together using this method. Very easy to
    # use!
    #
    # @example
    #   image.combine_options do |c|
    #     c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
    #     c.thumbnail "300x500>"
    #     c.background "blue"
    #   end
    #
    # @yield [MiniMagick::Tool::Mogrify]
    # @see http://www.imagemagick.org/script/mogrify.php
    # @return [self]
    #
    def combine_options(&block)
      mogrify(&block)
    end

    ##
    # If an unknown method is called then it is sent through the mogrify
    # program.
    #
    # @see http://www.imagemagick.org/script/mogrify.php
    # @return [self]
    #
    def method_missing(name, *args)
      mogrify do |builder|
        if builder.respond_to?(name)
          builder.send(name, *args)
        else
          super
        end
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      MiniMagick::Tool::Mogrify.new.respond_to?(method_name, include_private)
    end

    ##
    # Writes the temporary file out to either a file location (by passing in a
    # String) or by passing in a Stream that you can #write(chunk) to
    # repeatedly
    #
    # @param output_to [String, Pathname, #read] Some kind of stream object
    #   that needs to be read or a file path as a String
    #
    def write(output_to)
      case output_to
      when String, Pathname
        if layer?
          MiniMagick::Tool::Convert.new do |builder|
            builder << path
            builder << output_to
          end
        else
          FileUtils.copy_file path, output_to unless path == output_to.to_s
        end
      else
        IO.copy_stream File.open(path, "rb"), output_to
      end
    end

    ##
    # @example
    #  first_image = MiniMagick::Image.open "first.jpg"
    #  second_image = MiniMagick::Image.open "second.jpg"
    #  result = first_image.composite(second_image) do |c|
    #    c.compose "Over" # OverCompositeOp
    #    c.geometry "+20+20" # copy second_image onto first_image from (20, 20)
    #  end
    #  result.write "output.jpg"
    #
    # @see http://www.imagemagick.org/script/composite.php
    #
    def composite(other_image, output_extension = type.downcase, mask = nil)
      output_tempfile = MiniMagick::Utilities.tempfile(".#{output_extension}")

      MiniMagick::Tool::Composite.new do |composite|
        yield composite if block_given?
        composite << other_image.path
        composite << path
        composite << mask.path if mask
        composite << output_tempfile.path
      end

      Image.new(output_tempfile.path, output_tempfile)
    end

    ##
    # Collapse images with sequences to the first frame (i.e. animated gifs) and
    # preserve quality.
    #
    # @param frame [Integer] The frame to which to collapse to, defaults to `0`.
    # @return [self]
    #
    def collapse!(frame = 0)
      mogrify(frame) { |builder| builder.quality(100) }
    end

    ##
    # Destroys the tempfile (created by {.open}) if it exists.
    #
    def destroy!
      @tempfile.unlink if @tempfile
    end

    ##
    # Runs `identify` on itself. Accepts an optional block for adding more
    # options to `identify`.
    #
    # @example
    #   image = MiniMagick::Image.open("image.jpg")
    #   image.identify do |b|
    #     b.verbose
    #   end # runs `identify -verbose image.jpg`
    # @return [String] Output from `identify`
    # @yield [MiniMagick::Tool::Identify]
    #
    def identify
      MiniMagick::Tool::Identify.new do |builder|
        yield builder if block_given?
        builder << path
      end
    end

    # @private
    def run_command(tool_name, *args)
      MiniMagick::Tool.const_get(tool_name.capitalize).new do |builder|
        args.each do |arg|
          builder << arg
        end
      end
    end

    def mogrify(page = nil)
      @info.clear

      MiniMagick::Tool::Mogrify.new do |builder|
        builder.instance_eval do
          def format(*args)
            fail NoMethodError,
              "you must call #format on a MiniMagick::Image directly"
          end
        end
        yield builder if block_given?
        builder << (page ? "#{path}[#{page}]" : path)
      end

      self
    end

    def layer?
      path =~ /\[\d+\]$/
    end

  end
end
