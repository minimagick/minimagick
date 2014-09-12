require 'tempfile'
require 'subexec'
require 'stringio'
require 'pathname'

module MiniMagick
  class Image
    # @return [String] The location of the current working file
    attr_writer :path

    def path
      run_queue if @command_queued
      MiniMagick::Utilities.path(@path)
    end

    # Class Methods
    # -------------
    class << self
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
      def read(stream, ext = nil)
        if stream.is_a?(String)
          stream = StringIO.new(stream)
        elsif stream.is_a?(StringIO)
          # Do nothing, we want a StringIO-object
        elsif stream.respond_to? :path
          if File.respond_to?(:binread)
            stream = StringIO.new File.binread(stream.path.to_s)
          else
            stream = StringIO.new File.open(stream.path.to_s, 'rb') { |f| f.read }
          end
        end

        create(ext) do |f|
          while chunk = stream.read(8192)
            f.write(chunk)
          end
        end
      end

      # @deprecated Please use Image.read instead!
      def from_blob(blob, ext = nil)
        warn 'Warning: MiniMagick::Image.from_blob method is deprecated. Instead, please use Image.read'
        create(ext) { |f| f.write(blob) }
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
      def import_pixels(blob, columns, rows, depth, map, format = 'png')
        # Create an image object with the raw pixel data string:
        image = create('.dat', false) { |f| f.write(blob) }
        # Use ImageMagick to convert the raw data file to an image file of the
        # desired format:
        converted_image_path = image.path[0..-4] + format
        arguments = ['-size', "#{columns}x#{rows}", '-depth', "#{depth}", "#{map}:#{image.path}", "#{converted_image_path}"]
        # Example: convert -size 256x256 -depth 16 gray:blob.dat blob.png
        cmd = CommandBuilder.new('convert', *arguments)
        image.run(cmd)
        # Update the image instance with the path of the properly formatted
        # image, and return:
        image.path = converted_image_path
        image
      end

      # Opens a specific image file either on the local file system or at a URI.
      #
      # Use this if you don't want to overwrite the image file.
      #
      # Extension is either guessed from the path or you can specify it as a
      # second parameter.
      #
      # If you pass in what looks like a URL, we require 'open-uri' before
      # opening it.
      #
      # @param file_or_url [String] Either a local file path or a URL that
      #   open-uri can read
      # @param ext [String] Specify the extension you want to read it as
      # @return [Image] The loaded image
      def open(file_or_url, ext = nil)
        file_or_url = file_or_url.to_s # Force String... Hell or high water
        if file_or_url.include?('://')
          require 'open-uri'
          ext ||= File.extname(URI.parse(file_or_url).path)
          Kernel.open(file_or_url) do |f|
            read(f, ext)
          end
        else
          ext ||= File.extname(file_or_url)
          File.open(file_or_url, 'rb') do |f|
            read(f, ext)
          end
        end
      end

      # @deprecated Please use MiniMagick::Image.open(file_or_url) now
      def from_file(file, ext = nil)
        warn 'Warning: MiniMagick::Image.from_file is now deprecated. Please use Image.open'
        open(file, ext)
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
      def create(ext = nil, validate = MiniMagick.validate_on_create, &block)
        tempfile = Tempfile.new(['mini_magick', ext.to_s.downcase])
        tempfile.binmode
        block.call(tempfile)
        tempfile.close

        image = new(tempfile.path, tempfile)

        fail MiniMagick::Invalid if validate && !image.valid?
        return image
      ensure
        tempfile.close if tempfile
      end
    end

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
      reset_queue
    end

    def reset_queue
      @command_queued = false
      @queue = MiniMagick::CommandBuilder.new('mogrify')
      @info.clear
    end

    def run_queue
      return nil unless @command_queued
      @queue << MiniMagick::Utilities.path(@path)
      run(@queue)
      reset_queue
    end

    # Checks to make sure that MiniMagick can read the file and understand it.
    #
    # This uses the 'identify' command line utility to check the file. If you
    # are having issues with this, then please work directly with the
    # 'identify' command and see if you can figure out what the issue is.
    #
    # @return [Boolean]
    def valid?
      run_command('identify', path)
      true
    rescue MiniMagick::Invalid
      false
    end

    def info(key)
      run_queue if @command_queued

      @info[key.to_s]
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

      # Why do I go to the trouble of putting in newlines? Because otherwise
      # animated gifs screw everything up
      retrieved = info(value) ||
        case value
        when 'colorspace'
          run_command('identify', '-format', '%r\n', path).split("\n")[0].strip
        when 'format'
          run_command('identify', '-format', '%m\n', path).split("\n")[0]
        when 'dimensions', 'width', 'height'
          dimensions = run_command(
            'identify', '-format', MiniMagick::Utilities.windows? ? '"%w %h\n"' : '%w %h\n', path
          ).split("\n")[0].split.map { |v| v.to_i }

          @info["dimensions"] = dimensions
          @info["width"], @info["height"] = @info["dimensions"]
          @info[value]
        when 'size'
          File.size(path) # Do this because calling identify -format "%b" on an animated gif fails!
        when 'original_at'
          # Get the EXIF original capture as a Time object
          Time.local(*self['EXIF:DateTimeOriginal'].split(/:|\s+/)) rescue nil
        when /^EXIF\:/i
          result = run_command('identify', '-format', "%[#{value}]", path).chomp
          if result.include?(',')
            read_character_data(result)
          else
            result
          end
        else
          run_command('identify', '-format', value, path).split("\n")[0]
        end

      @info[value] = retrieved unless retrieved.nil?
      @info[value]
    end

    # Sends raw commands to imagemagick's `mogrify` command. The image path is
    # automatically appended to the command.
    #
    # Remember, we are always acting on this instance of the Image when messing
    # with this.
    #
    # @return [String] Whatever the result from the command line is. May not be
    #   terribly useful.
    def <<(*args)
      run_command('mogrify', *args << path)
    end

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
      run_queue if @command_queued

      old_path = path

      if @tempfile
        new_tempfile = Tempfile.new(["mini_magick", ".#{format}"])
        new_path = new_tempfile.path
      else
        new_path = File.basename(@path, ".*") + ".#{format}"
      end

      cmd = CommandBuilder.new("convert", (page ? "#{@path}[#{page}]" : @path))
      yield cmd if block_given?
      cmd << new_path
      run(cmd)

      if @tempfile
        @tempfile.unlink
        @tempfile = new_tempfile
        @tempfile.close
      else
        File.delete(old_path) if old_path != new_path
      end

      self.path = new_path
    end

    # Collapse images with sequences to the first frame (i.e. animated gifs) and
    # preserve quality
    def collapse!
      run_command('mogrify', '-quality', '100', "#{path}[0]")
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
      run_queue if @command_queued

      if output_to.kind_of?(String) || output_to.kind_of?(Pathname) || !output_to.respond_to?(:write)
        FileUtils.copy_file path, output_to
        if MiniMagick.validate_on_write
          run_command(
            'identify', MiniMagick::Utilities.path(output_to.to_s)
          ) # Verify that we have a good image
        end
      else # stream
        File.open(path, 'rb') do |f|
          f.binmode
          while chunk = f.read(8192)
            output_to.write(chunk)
          end
        end
        output_to
      end
    end

    # Gives you raw image data back
    # @return [String] binary string
    def to_blob
      run_queue if @command_queued

      f = File.new path
      f.binmode
      f.read
    ensure
      f.close if f
    end

    def mime_type
      format = self[:format]
      'image/' + format.to_s.downcase
    end

    # If an unknown method is called then it is sent through the mogrify
    # program.
    #
    # @see http://www.imagemagick.org/script/mogrify.php
    def method_missing(symbol, *args)
      @queue.send(symbol, *args)
      @command_queued = true
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
    # @yieldparam command [CommandBuilder]
    def combine_options
      if block_given?
        yield @queue
        @command_queued = true
      end
    end

    def composite(other_image, output_extension = 'jpg', mask = nil, &block)
      run_queue if @command_queued
      begin
        second_tempfile = Tempfile.new(output_extension)
        second_tempfile.binmode
      ensure
        second_tempfile.close
      end

      command = CommandBuilder.new('composite')
      block.call(command) if block
      command.push(other_image.path)
      command.push(path)
      command.push(mask.path) unless mask.nil?
      command.push(second_tempfile.path)

      run(command)
      Image.new(second_tempfile.path, second_tempfile)
    end

    def run_command(command, *args)
      run_queue if @command_queued

      if command == 'identify'
        args.unshift '-ping'  # -ping "efficiently determine image characteristics."
        args.unshift '-quiet' if MiniMagick.mogrify? && !MiniMagick.debug # graphicsmagick has no -quiet option.
      end

      run(CommandBuilder.new(command, *args))
    end

    def run(command_builder)
      command = command_builder.command

      sub = Subexec.run(command, :timeout => MiniMagick.timeout)

      if sub.exitstatus != 0
        # Raise the appropriate error
        if sub.output =~ /no decode delegate/i || sub.output =~ /did not return an image/i
          fail Invalid, sub.output
        else
          # TODO: should we do something different if the command times out ...?
          # its definitely better for logging.. Otherwise we don't really know
          fail Error, "Command (#{command.inspect.gsub("\\", "")}) failed: #{{ :status_code => sub.exitstatus, :output => sub.output }.inspect}"
        end
      else
        sub.output
      end
    end

    private

    # Sometimes we get back a list of character values
    def read_character_data(string)
      string.scan(/\d+/).map(&:to_i).map(&:chr).join
    end
  end
end
