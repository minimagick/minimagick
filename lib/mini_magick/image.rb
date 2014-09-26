require 'tempfile'
require 'stringio'
require 'pathname'
require 'uri'
require 'open-uri'

module MiniMagick
  class Image

    # This is the primary loading method used by all of the other class
    # methods.
    #
    # Use this to pass in a stream object. Must respond to Object#read(size)
    # or be a binary string object (BLOBBBB)
    #
    # As a change from the old API, please try and use IOStream objects. They
    # are much, much better and more efficient!
    #
    # Probably easier to use the #open method if you want to open a file or a
    # URL.
    #
    # @param stream [IOStream, String] Some kind of stream object that needs
    #   to be read or is a binary String blob!
    # @param ext [String] A manual extension to use for reading the file. Not
    #   required, but if you are having issues, give this a try.
    # @return [Image]
    def self.read(stream, ext = nil)
      if stream.is_a?(String)
        stream = StringIO.new(stream)
      end

      create(ext) { |file| IO.copy_stream(stream, file) }
    end

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
    # @return [Image] The loaded image.
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
          convert << output_path.inspect
        end

        image.path = output_path
      end
    end

    # Opens a specific image file either on the local file system or at a URI.
    # Use this if you don't want to overwrite the image file.
    #
    # Extension is either guessed from the path or you can specify it as a
    # second parameter.
    #
    # @param file_or_url [String] Either a local file path or a URL that
    #   open-uri can read
    # @param ext [String] Specify the extension you want to read it as
    # @return [Image] The loaded image
    def self.open(path_or_url, ext = nil)
      ext ||=
        if path_or_url.to_s =~ URI.regexp
          File.extname(URI(path_or_url).path)
        else
          File.extname(path_or_url)
        end

      Kernel.open(path_or_url, "rb") do |file|
        read(file, ext)
      end
    end

    # Used to create a new Image object data-copy. Not used to "paint" or
    # that kind of thing.
    #
    # Takes an extension in a block and can be used to build a new Image
    # object. Used by both #open and #read to create a new object! Ensures we
    # have a good tempfile!
    #
    # @param ext [String] Specify the extension you want to read it as
    # @param validate [Boolean] If false, skips validation of the created
    #   image. Defaults to true.
    # @yield [IOStream] You can #write bits to this object to create the new
    #   Image
    # @return [Image] The created image
    def self.create(ext = nil, validate = MiniMagick.validate_on_create, &block)
      tempfile = Tempfile.new(['mini_magick', ext.to_s.downcase])
      tempfile.binmode
      yield tempfile
      tempfile.close

      new(tempfile.path, tempfile).tap do |image|
        image.validate! if validate
      end
    end

    # @return [String] The location of the current working file
    attr_accessor :path

    # Create a new MiniMagick::Image object
    #
    # _DANGER_: The file location passed in here is the *working copy*. That
    # is, it gets *modified*. you can either copy it yourself or use the
    # MiniMagick::Image.open(path) method which creates a temporary file for
    # you and protects your original!
    #
    # @param input_path [String] The location of an image file
    # @todo Allow this to accept a block that can pass off to
    #   Image#combine_options
    def initialize(input_path, tempfile = nil)
      @path = input_path
      @tempfile = tempfile
      @info = {}
    end

    # Checks to make sure that MiniMagick can read the file and understand it.
    #
    # This uses the 'identify' command line utility to check the file. If you
    # are having issues with this, then please work directly with the
    # 'identify' command and see if you can figure out what the issue is.
    #
    # @return [Boolean]
    def valid?
      validate!
      true
    rescue MiniMagick::Invalid
      false
    end

    # Runs `identify` on the current image, and raises an error if it doesn't
    # pass.
    #
    # @raises [MiniMagick::Invalid]
    def validate!
      identify
    rescue MiniMagick::Error => error
      raise MiniMagick::Invalid, error.message
    end

    # A rather low-level way to interact with the "identify" command. No nice
    # API here, just the crazy stuff you find in ImageMagick. See the examples
    # listed!
    #
    # @example
    #    image["format"]      #=> "TIFF"
    #    image["height"]      #=> 41 (pixels)
    #    image["width"]       #=> 50 (pixels)
    #    image["colorspace"]  #=> "DirectClassRGB"
    #    image["dimensions"]  #=> [50, 41]
    #    image["size"]        #=> 2050 (bits)
    #    image["original_at"] #=> 2005-02-23 23:17:24 +0000 (Read from Exif data)
    #    image["EXIF:ExifVersion"] #=> "0220" (Can read anything from Exif)
    #
    # @param format [String] A format for the "identify" command
    # @see http://www.imagemagick.org/script/command-line-options.php#format
    # @return [String, Numeric, Array, Time, Object] Depends on the method
    #   called! Defaults to String for unknown commands
    def [](value)
      value = value.to_s
      identify = MiniMagick::Tool::Identify.new
      # Why do I go to the trouble of putting in newlines? Because otherwise
      # animated gifs screw everything up
      @info[value] ||=
        case value
        when 'colorspace'
          (identify.format('%r\n') << path.inspect).call
        when 'format'
          (identify.format('%m\n') << path.inspect).call.split("\n").first
        when 'dimensions', 'width', 'height'
          dimensions = (identify.format('%w %h\n') << path.inspect).call.split.map(&:to_i)
          @info["dimensions"] = dimensions
          @info["width"], @info["height"] = @info["dimensions"]
          @info[value]
        when 'size'
          File.size(path) # Do this because calling identify -format "%b" on an animated gif fails!
        when 'original_at'
          # Get the EXIF original capture as a Time object
          Time.local(*self['EXIF:DateTimeOriginal'].split(/:|\s+/)) rescue nil
        when /^EXIF\:/i
          result = (identify.format("%[#{value}]") << path).call
          if result.include?(',')
            result.scan(/\d+/).map(&:to_i).map(&:chr).join
          else
            result
          end
        else
          (identify.format(value) << path).call
        end
    end
    alias info []

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
    # @return [nil]
    def format(format, page = 0)
      @info.clear

      if @tempfile
        new_tempfile = Tempfile.new(["mini_magick", ".#{format}"])
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
        @tempfile.close
      else
        File.delete(path) unless path == new_path
      end

      self.path = new_path
    end

    # Collapse images with sequences to the first frame (i.e. animated gifs) and
    # preserve quality
    def collapse!
      @info.clear
      mogrify(0) { |builder| builder.quality(100) }
    end

    # Writes the temporary file out to either a file location (by passing in a
    # String) or by passing in a Stream that you can #write(chunk) to
    # repeatedly
    #
    # @param output_to [IOStream, String] Some kind of stream object that needs
    #   to be read or a file path as a String
    # @return [IOStream, Boolean] If you pass in a file location [String] then
    #   you get a success boolean. If its a stream, you get it back.
    def write(output_to)
      case output_to
      when String, Pathname
        FileUtils.copy_file path, output_to
      else
        IO.copy_stream File.open(path, "rb"), output_to
      end
    end

    # Gives you raw image data back
    # @return [String] binary string
    def to_blob
      File.binread(path)
    end

    def mime_type
      "image/#{self[:format].downcase}"
    end

    # If an unknown method is called then it is sent through the mogrify
    # program.
    #
    # @see http://www.imagemagick.org/script/mogrify.php
    def method_missing(name, *args)
      @info.clear
      mogrify { |builder| builder.send(name, *args) }
    end

    # You can use multiple commands together using this method. Very easy to
    # use!
    #
    # @example
    #   image.combine_options do |c|
    #     c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
    #     c.thumbnail "300x500>"
    #     c.background background
    #   end
    #
    # @yieldparam command [MiniMagick::Tool::Mogrify
    def combine_options(&block)
      @info.clear
      mogrify(&block)
    end

    def composite(other_image, output_extension = 'jpg', mask = nil)
      begin
        second_tempfile = Tempfile.new(["magick", ".#{output_extension}"])
        second_tempfile.binmode
      ensure
        second_tempfile.close
      end

      MiniMagick::Tool::Composite.new do |composite|
        yield composite if block_given?
        composite << other_image.path.inspect
        composite << path.inspect
        composite << mask.path.inspect if mask
        composite << second_tempfile.path.inspect
      end

      Image.new(second_tempfile.path, second_tempfile)
    end

    def destroy!
      @tempfile.unlink if @tempfile
    end

    private

    [:identify, :mogrify].each do |tool_name|
      define_method(tool_name) do |page = nil, &block|
        MiniMagick::Tool.const_get(tool_name.capitalize).new do |builder|
          block.call(builder) if block
          builder << (page ? "#{path}[#{page}]" : path).inspect
        end
      end
    end

  end
end
