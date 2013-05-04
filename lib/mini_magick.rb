require 'tempfile'
require 'subexec'
require 'stringio'
require 'pathname'
require 'shellwords'

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
      if `type -P mogrify`.size > 0
        return
      elsif `type -P gm`.size > 0
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

  MOGRIFY_COMMANDS = %w{adaptive-blur adaptive-resize adaptive-sharpen adjoin affine alpha annotate antialias append attenuate authenticate auto-gamma auto-level auto-orient backdrop background bench bias black-point-compensation black-threshold blend blue-primary blue-shift blur border bordercolor borderwidth brightness-contrast cache caption cdl channel charcoal chop clamp clip clip-mask clip-path clone clut coalesce colorize colormap color-matrix colors colorspace combine comment compose composite compress contrast contrast-stretch convolve crop cycle debug decipher deconstruct define delay delete density depth descend deskew despeckle direction displace display dispose dissimilarity-threshold dissolve distort dither draw duplicate edge emboss encipher encoding endian enhance equalize evaluate evaluate-sequence extent extract family features fft fill filter flatten flip floodfill flop font foreground format frame function fuzz fx gamma gaussian-blur geometry gravity green-primary hald-clut help highlight-color iconGeometry iconic identify ift immutable implode insert intent interlace interpolate interline-spacing interword-spacing kerning label lat layers level level-colors limit linear-stretch linewidth liquid-rescale list log loop lowlight-color magnify map mask mattecolor median metric mode modulate monitor monochrome morph morphology mosaic motion-blur name negate noise normalize opaque ordered-dither orient page paint path pause pen perceptible ping pointsize polaroid poly posterize precision preview print process profile quality quantize quiet radial-blur raise random-threshold red-primary regard-warnings region remap remote render repage resample resize respect-parentheses reverse roll rotate sample sampling-factor scale scene screen seed segment selective-blur separate sepia-tone set shade shadow shared-memory sharpen shave shear sigmoidal-contrast silent size sketch smush snaps solarize sparse-color splice spread statistic stegano stereo stretch strip stroke strokewidth style subimage-search swap swirl synchronize taint text-font texture threshold thumbnail tile tile-offset tint title transform transparent transparent-color transpose transverse treedepth trim type undercolor unique-colors units unsharp update verbose version view vignette virtual-pixel visual watermark wave weight white-point white-threshold window window-group write}

  IMAGE_CREATION_OPERATORS = %w{canvas caption gradient label logo pattern plasma radial radient rose text tile xc }

  class Error < RuntimeError; end
  class Invalid < StandardError; end

  class Image
    # @return [String] The location of the current working file
    attr_accessor :path

    # Class Methods
    # -------------
    class << self
      # This is the primary loading method used by all of the other class methods.
      #
      # Use this to pass in a stream object. Must respond to Object#read(size) or be a binary string object (BLOBBBB)
      #
      # As a change from the old API, please try and use IOStream objects. They are much, much better and more efficient!
      #
      # Probably easier to use the #open method if you want to open a file or a URL.
      #
      # @param stream [IOStream, String] Some kind of stream object that needs to be read or is a binary String blob!
      # @param ext [String] A manual extension to use for reading the file. Not required, but if you are having issues, give this a try.
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
            stream = StringIO.new File.open(stream.path.to_s,"rb") { |f| f.read }
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
        warn "Warning: MiniMagick::Image.from_blob method is deprecated. Instead, please use Image.read"
        create(ext) { |f| f.write(blob) }
      end

      # Creates an image object from a binary string blob which contains raw pixel data (i.e. no header data).
      #
      # === Returns
      #
      # * [Image] The loaded image.
      #
      # === Parameters
      #
      # * [blob] <tt>String</tt> -- Binary string blob containing raw pixel data.
      # * [columns] <tt>Integer</tt> -- Number of columns.
      # * [rows] <tt>Integer</tt> -- Number of rows.
      # * [depth] <tt>Integer</tt> -- Bit depth of the encoded pixel data.
      # * [map] <tt>String</tt> -- A code for the mapping of the pixel data. Example: 'gray' or 'rgb'.
      # * [format] <tt>String</tt> -- The file extension of the image format to be used when creating the image object. Defaults to 'png'.
      #
      def import_pixels(blob, columns, rows, depth, map, format="png")
        # Create an image object with the raw pixel data string:
        image = create(".dat", validate = false) { |f| f.write(blob) }
        # Use ImageMagick to convert the raw data file to an image file of the desired format:
        converted_image_path = image.path[0..-4] + format
        arguments = ["-size", "#{columns}x#{rows}", "-depth", "#{depth}", "#{map}:#{image.path}", "#{converted_image_path}"]
        cmd = CommandBuilder.new("convert", *arguments) #Example: convert -size 256x256 -depth 16 gray:blob.dat blob.png
        image.run(cmd)
        # Update the image instance with the path of the properly formatted image, and return:
        image.path = converted_image_path
        image
      end

      # Opens a specific image file either on the local file system or at a URI.
      #
      # Use this if you don't want to overwrite the image file.
      #
      # Extension is either guessed from the path or you can specify it as a second parameter.
      #
      # If you pass in what looks like a URL, we require 'open-uri' before opening it.
      #
      # @param file_or_url [String] Either a local file path or a URL that open-uri can read
      # @param ext [String] Specify the extension you want to read it as
      # @return [Image] The loaded image
      def open(file_or_url, ext = nil)
        file_or_url = file_or_url.to_s # Force it to be a String... hell or highwater
        if file_or_url.include?("://")
          require 'open-uri'
          ext ||= File.extname(URI.parse(file_or_url).path)
          self.read(Kernel::open(file_or_url), ext)
        else
          ext ||= File.extname(file_or_url)
          File.open(file_or_url, "rb") do |f|
            self.read(f, ext)
          end
        end
      end

      # @deprecated Please use MiniMagick::Image.open(file_or_url) now
      def from_file(file, ext = nil)
        warn "Warning: MiniMagick::Image.from_file is now deprecated. Please use Image.open"
        open(file, ext)
      end

      # Used to create a new Image object data-copy. Not used to "paint" or that kind of thing.
      #
      # Takes an extension in a block and can be used to build a new Image object. Used
      # by both #open and #read to create a new object! Ensures we have a good tempfile!
      #
      # @param ext [String] Specify the extension you want to read it as
      # @param validate [Boolean] If false, skips validation of the created image. Defaults to true.
      # @yield [IOStream] You can #write bits to this object to create the new Image
      # @return [Image] The created image
      def create(ext = nil, validate = true, &block)
        begin
          tempfile = Tempfile.new(['mini_magick', ext.to_s.downcase])
          tempfile.binmode
          block.call(tempfile)
          tempfile.close

          image = self.new(tempfile.path, tempfile)

          if validate and !image.valid?
            raise MiniMagick::Invalid
          end
          return image
        ensure
          tempfile.close if tempfile
        end
      end
    end

    # Create a new MiniMagick::Image object
    #
    # _DANGER_: The file location passed in here is the *working copy*. That is, it gets *modified*.
    # you can either copy it yourself or use the MiniMagick::Image.open(path) method which creates a
    # temporary file for you and protects your original!
    #
    # @param input_path [String] The location of an image file
    # @todo Allow this to accept a block that can pass off to Image#combine_options
    def initialize(input_path, tempfile = nil)
      @path = input_path
      @tempfile = tempfile # ensures that the tempfile will stick around until this image is garbage collected.
    end

    # Checks to make sure that MiniMagick can read the file and understand it.
    #
    # This uses the 'identify' command line utility to check the file. If you are having
    # issues with this, then please work directly with the 'identify' command and see if you
    # can figure out what the issue is.
    #
    # @return [Boolean]
    def valid?
      run_command("identify", path)
      true
    rescue MiniMagick::Invalid
      false
    end

    # A rather low-level way to interact with the "identify" command. No nice API here, just
    # the crazy stuff you find in ImageMagick. See the examples listed!
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
    # @see For reference see http://www.imagemagick.org/script/command-line-options.php#format
    # @return [String, Numeric, Array, Time, Object] Depends on the method called! Defaults to String for unknown commands
    def [](value)
      # Why do I go to the trouble of putting in newlines? Because otherwise animated gifs screw everything up
      case value.to_s
      when "colorspace"
        run_command("identify", "-format", '%r\n', path).split("\n")[0].strip
      when "format"
        run_command("identify", "-format", '%m\n', path).split("\n")[0]
      when "height"
        run_command("identify", "-format", '%h\n', path).split("\n")[0].to_i
      when "width"
        run_command("identify", "-format", '%w\n', path).split("\n")[0].to_i
      when "dimensions"
        run_command("identify", "-format", '%w %h\n', path).split("\n")[0].split.map{|v|v.to_i}
      when "size"
        File.size(path) # Do this because calling identify -format "%b" on an animated gif fails!
      when "original_at"
        # Get the EXIF original capture as a Time object
        Time.local(*self["EXIF:DateTimeOriginal"].split(/:|\s+/)) rescue nil
      when /^EXIF\:/i
        result = run_command('identify', '-format', "%[#{value}]", path).chop
        if result.include?(",")
          read_character_data(result)
        else
          result
        end
      else
        run_command('identify', '-format', value, path).split("\n")[0]
      end
    end

    # Sends raw commands to imagemagick's `mogrify` command. The image path is automatically appended to the command.
    #
    # Remember, we are always acting on this instance of the Image when messing with this.
    #
    # @return [String] Whatever the result from the command line is. May not be terribly useful.
    def <<(*args)
      run_command("mogrify", *args << path)
    end

    # This is used to change the format of the image. That is, from "tiff to jpg" or something like that.
    # Once you run it, the instance is pointing to a new file with a new extension!
    #
    # *DANGER*: This renames the file that the instance is pointing to. So, if you manually opened the
    # file with Image.new(file_path)... then that file is DELETED! If you used Image.open(file) then
    # you are ok. The original file will still be there. But, any changes to it might not be...
    #
    # Formatting an animation into a non-animated type will result in ImageMagick creating multiple
    # pages (starting with 0).  You can choose which page you want to manipulate.  We default to the
    # first page.
    #
    # If you would like to convert between animated formats, pass nil as your
    # page and ImageMagick will copy all of the pages.
    #
    # @param format [String] The target format... like 'jpg', 'gif', 'tiff', etc.
    # @param page [Integer] If this is an animated gif, say which 'page' you want
    # with an integer. Default 0 will convert only the first page; 'nil' will
    # convert all pages.
    # @return [nil]
    def format(format, page = 0)
      c = CommandBuilder.new('mogrify', '-format', format)
      yield c if block_given?
      if page
        c << "#{path}[#{page}]"
      else
        c << path
      end
      run(c)

      old_path = path
      self.path = path.sub(/(\.\w*)?$/, ".#{format}")
      File.delete(old_path) if old_path != path

      unless File.exists?(path)
        raise MiniMagick::Error, "Unable to format to #{format}"
      end
    end

    # Collapse images with sequences to the first frame (ie. animated gifs) and
    # preserve quality
    def collapse!
      run_command("mogrify", "-quality", "100", "#{path}[0]")
    end

    # Writes the temporary file out to either a file location (by passing in a String) or by
    # passing in a Stream that you can #write(chunk) to repeatedly
    #
    # @param output_to [IOStream, String] Some kind of stream object that needs to be read or a file path as a String
    # @return [IOStream, Boolean] If you pass in a file location [String] then you get a success boolean. If its a stream, you get it back.
    # Writes the temporary image that we are using for processing to the output path
    def write(output_to)
      if output_to.kind_of?(String) || !output_to.respond_to?(:write)
        FileUtils.copy_file path, output_to
        run_command "identify", output_to.to_s # Verify that we have a good image
      else # stream
        File.open(path, "rb") do |f|
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
      f = File.new path
      f.binmode
      f.read
    ensure
      f.close if f
    end

    def mime_type
      format = self[:format]
      "image/" + format.to_s.downcase
    end

    # If an unknown method is called then it is sent through the mogrify program
    # Look here to find all the commands (http://www.imagemagick.org/script/mogrify.php)
    def method_missing(symbol, *args)
      combine_options do |c|
        c.send(symbol, *args)
      end
    end

    # You can use multiple commands together using this method. Very easy to use!
    #
    # @example
    #   image.combine_options do |c|
    #     c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
    #     c.thumbnail "300x500>"
    #     c.background background
    #   end
    #
    # @yieldparam command [CommandBuilder]
    def combine_options(tool = "mogrify", &block)
      c = CommandBuilder.new(tool)

      c << path if tool.to_s == "convert"
      block.call(c)
      c << path
      run(c)
    end

    def composite(other_image, output_extension = 'jpg', &block)
      begin
        second_tempfile = Tempfile.new(output_extension)
        second_tempfile.binmode
      ensure
        second_tempfile.close
      end

      command = CommandBuilder.new("composite")
      block.call(command) if block
      command.push(other_image.path)
      command.push(self.path)
      command.push(second_tempfile.path)

      run(command)
      return Image.new(second_tempfile.path, second_tempfile)
    end

    def run_command(command, *args)
      # -ping "efficiently determine image characteristics."
      if command == 'identify'
        args.unshift '-ping'
        args.unshift '-quiet' unless MiniMagick.processor.to_s == 'gm'
      end

      run(CommandBuilder.new(command, *args))
    end

    def run(command_builder)
      command = command_builder.command

      sub = Subexec.run(command, :timeout => MiniMagick.timeout)

      if sub.exitstatus != 0
        # Clean up after ourselves in case of an error
        destroy!

        # Raise the appropriate error
        if sub.output =~ /no decode delegate/i || sub.output =~ /did not return an image/i
          raise Invalid, sub.output
        else
          # TODO: should we do something different if the command times out ...?
          # its definitely better for logging.. otherwise we dont really know
          raise Error, "Command (#{command.inspect.gsub("\\", "")}) failed: #{{:status_code => sub.exitstatus, :output => sub.output}.inspect}"
        end
      else
        sub.output
      end
    end

    def destroy!
      return if @tempfile.nil?
      File.unlink(@tempfile.path) if File.exists?(@tempfile.path)
      @tempfile = nil
    end

    private
      # Sometimes we get back a list of character values
      def read_character_data(list_of_characters)
        chars = list_of_characters.gsub(" ", "").split(",")
        result = ""
        chars.each do |val|
          result << ("%c" % val.to_i)
        end
        result
      end
  end

  class CommandBuilder
    def initialize(tool, *options)
      @tool = tool
      @args = []
      options.each { |arg| push(arg) }
    end

    def command
      com = "#{@tool} #{args.join(' ')}".strip
      com = "#{MiniMagick.processor} #{com}" unless MiniMagick.processor.nil?

      com = File.join MiniMagick.processor_path, com unless MiniMagick.processor_path.nil?
      com.strip
    end

    def args
      @args.map(&:shellescape)
    end

    # Add each mogrify command in both underscore and dash format
    MOGRIFY_COMMANDS.each do |mogrify_command|

      # Example of what is generated here:
      #
      # def auto_orient(*options)
      #   add_command("auto-orient", *options)
      #   self
      # end
      # alias_method :"auto-orient", :auto_orient

      dashed_command      = mogrify_command.to_s.gsub("_","-")
      underscored_command = mogrify_command.to_s.gsub("-","_")

      define_method(underscored_command) do |*options|
        add_command(__method__.to_s.gsub("_","-"), *options)
        self
      end
      alias_method dashed_command, underscored_command
    end

    def format(*options)
      raise Error, "You must call 'format' on the image object directly!"
    end

    IMAGE_CREATION_OPERATORS.each do |operator|
      define_method operator do |*options|
        add_creation_operator(__method__.to_s, *options)
        self
      end
    end

    def +(*options)
      push(@args.pop.gsub(/^-/, '+'))
      if options.any?
        options.each do |o|
          push o
        end
      end
    end

    def add_command(command, *options)
      push "-#{command}"
      if options.any?
        options.each do |o|
          push o
        end
      end
    end

    def add_creation_operator(command, *options)
      creation_command = command
      if options.any?
        options.each do |option|
          creation_command << ":#{option}"
        end
      end
      push creation_command
    end

    def push(arg)
      @args << arg.to_s.strip
    end
    alias :<< :push
  end
end
