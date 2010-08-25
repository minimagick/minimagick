require 'tempfile'
require 'subexec'

module MiniMagick
  class << self
    attr_accessor :processor
    attr_accessor :timeout
  end
  
  MOGRIFY_COMMANDS = %w{adaptive-blur adaptive-resize adaptive-sharpen adjoin affine alpha annotate antialias append authenticate auto-gamma auto-level auto-orient background bench iterations bias black-threshold blue-primary point blue-shift factor blur border bordercolor brightness-contrast caption string cdl filename channel type charcoal radius chop clip clamp clip-mask filename clip-path id clone index clut contrast-stretch coalesce colorize color-matrix colors colorspace type combine comment string compose operator composite compress type contrast convolve coefficients crop cycle amount decipher filename debug events define format:option deconstruct delay delete index density depth despeckle direction type display server dispose method distort type coefficients dither method draw string edge radius emboss radius encipher filename encoding type endian type enhance equalize evaluate operator evaluate-sequence operator extent extract family name fft fill filter type flatten flip floodfill flop font name format string frame function name fuzz distance fx expression gamma gaussian-blur geometry gravity type green-primary point help identify ifft implode amount insert index intent type interlace type interline-spacing interpolate method interword-spacing kerning label string lat layers method level limit type linear-stretch liquid-rescale log format loop iterations mask filename mattecolor median radius modulate monitor monochrome morph morphology method kernel motion-blur negate noise radius normalize opaque ordered-dither NxN orient type page paint radius ping pointsize polaroid angle posterize levels precision preview type print string process image-filter profile filename quality quantizespace quiet radial-blur angle raise random-threshold low,high red-primary point regard-warnings region remap filename render repage resample resize respect-parentheses roll rotate degrees sample sampling-factor scale scene seed segments selective-blur separate sepia-tone threshold set attribute shade degrees shadow sharpen shave shear sigmoidal-contrast size sketch solarize threshold splice spread radius strip stroke strokewidth stretch type style type swap indexes swirl degrees texture filename threshold thumbnail tile filename tile-offset tint transform transparent transparent-color transpose transverse treedepth trim type type undercolor unique-colors units type unsharp verbose version view vignette virtual-pixel method wave weight type white-point point white-threshold write filename}

  class Error < RuntimeError; end
  class Invalid < StandardError; end

  class Image
    attr :path
    attr :tempfile
    attr :output

    # Class Methods
    # -------------
    class << self
      def from_blob(blob, ext = nil)
        begin
          tempfile = Tempfile.new(['mini_magick', ext.to_s])
          tempfile.binmode
          tempfile.write(blob)
        ensure
          tempfile.close if tempfile
        end

        image = self.new(tempfile.path, tempfile)
        if !image.valid?
          raise MiniMagick::Invalid
        end
        image
      end

      def from_uri( uri )
        image = nil
        begin
          image = self.from_blob( uri.read )
        rescue Exception => e
          raise e
        end
        image
      end

      # Use this if you don't want to overwrite the image file
      def open(image_path)
        File.open(image_path, "rb") do |f|
          self.from_blob(f.read, File.extname(image_path))
        end
      end
      alias_method :from_file, :open
    end

    # Instance Methods
    # ----------------
    def initialize(input_path, tempfile=nil)
      @path = input_path
      @tempfile = tempfile # ensures that the tempfile will stick around until this image is garbage collected.
    end
    
    def valid?
      run_command("identify", @path)
      true
    rescue MiniMagick::Invalid
      false
    end

    # For reference see http://www.imagemagick.org/script/command-line-options.php#format
    def [](value)
      # Why do I go to the trouble of putting in newlines? Because otherwise animated gifs screw everything up
      case value.to_s
      when "format"
        run_command("identify", "-format", format_option("%m"), @path).split("\n")[0]
      when "height"
        run_command("identify", "-format", format_option("%h"), @path).split("\n")[0].to_i
      when "width"
        run_command("identify", "-format", format_option("%w"), @path).split("\n")[0].to_i
      when "dimensions"
        run_command("identify", "-format", format_option("%w %h"), @path).split("\n")[0].split.map{|v|v.to_i}
      when "size"
        File.size(@path) # Do this because calling identify -format "%b" on an animated gif fails!
      when "original_at"
        # Get the EXIF original capture as a Time object
        Time.local(*self["EXIF:DateTimeOriginal"].split(/:|\s+/)) rescue nil
      when /^EXIF\:/i
        result = run_command('identify', '-format', "\"%[#{value}]\"", @path).chop
        if result.include?(",")
          read_character_data(result)
        else
          result
        end
      else
        run_command('identify', '-format', "\"#{value}\"", @path).split("\n")[0]
      end
    end

    # Sends raw commands to imagemagick's mogrify command. The image path is automatically appended to the command
    def <<(*args)
      run_command("mogrify", *args << @path)
    end

    # This is a 'special' command because it needs to change @path to reflect the new extension
    # Formatting an animation into a non-animated type will result in ImageMagick creating multiple
    # pages (starting with 0).  You can choose which page you want to manipulate.  We default to the
    # first page.
    def format(format, page=0)
      run_command("mogrify", "-format", format, @path)

      old_path = @path.dup
      @path.sub!(/(\.\w*)?$/, ".#{format}")
      File.delete(old_path) unless old_path == @path

      unless File.exists?(@path)
        begin
          FileUtils.copy_file(@path.sub(".#{format}", "-#{page}.#{format}"), @path)
        rescue => ex
          raise MiniMagickError, "Unable to format to #{format}; #{ex}" unless File.exist?(@path)
        end
      end
    ensure
      Dir[@path.sub(/(\.\w+)?$/, "-[0-9]*.#{format}")].each do |fname|
        File.unlink(fname)
      end
    end
    
    # Collapse images with sequences to the first frame (ie. animated gifs) and
    # preserve quality
    def collapse!
      run_command("mogrify", "-quality", "100", "#{path}[0]")
    end

    # Writes the temporary image that we are using for processing to the output path
    def write(output_path)
      FileUtils.copy_file @path, output_path
      run_command "identify", output_path # Verify that we have a good image
    end

    # Give you raw data back
    def to_blob
      f = File.new @path
      f.binmode
      f.read
    ensure
      f.close if f
    end

    # If an unknown method is called then it is sent through the morgrify program
    # Look here to find all the commands (http://www.imagemagick.org/script/mogrify.php)
    def method_missing(symbol, *args)
      guessed_command_name = symbol.to_s.gsub('_','-')

      if MOGRIFY_COMMANDS.include?(guessed_command_name)
        args.push(@path) # push the path onto the end
        run_command("mogrify", "-#{guessed_command_name}", *args)
        self
      else
        super(symbol, *args)
      end
    end

    # You can use multiple commands together using this method
    def combine_options(&block)
      c = CommandBuilder.new('mogrify')
      block.call c
      c << @path
      run(c)
    end

    # Check to see if we are running on win32 -- we need to escape things differently
    def windows?
      !(RUBY_PLATFORM =~ /win32/).nil?
    end
    
    def composite(other_image, output_extension = 'jpg', &block)
      begin
        tempfile = Tempfile.new(output_extension)
        tempfile.binmode
      ensure
        tempfile.close
      end
      
      command = CommandBuilder.new("composite")
      block.call(command) if block
      command.push(other_image.path)
      command.push(self.path)
      command.push(tempfile.path)
      
      run(command)
      return Image.new(tempfile.path)
    end

    # Outputs a carriage-return delimited format string for Unix and Windows
    def format_option(format)
      windows? ? "#{format}\\n" : "#{format}\\\\n"
    end

    def run_command(command, *args)
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
          raise Error, "Command (#{command.inspect}) failed: #{{:status_code => sub.exitstatus, :output => sub.output}.inspect}"
        end
      else
        sub.output
      end
    end
    
    def destroy!
      return if tempfile.nil?
      File.unlink(tempfile.path)
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
    attr :args
    attr :command

    def initialize(command, *options)
      @command = command
      @args = []
  
      options.each { |val| push(val) }
    end
    
    def command
      "#{MiniMagick.processor} #{@command} #{@args.join(' ')}".strip
    end
    
    def method_missing(symbol, *args)
      guessed_command_name = symbol.to_s.gsub('_','-')
      if MOGRIFY_COMMANDS.include?(guessed_command_name)
        # This makes sure we always quote if we are passed a single
        # arguement with spaces in it
        if (args.size == 1) && (args.first.to_s.include?(' ') || args.first.to_s.include?('#'))
          push("-#{guessed_command_name}")
          push(args.join(" "))
        else
          push("-#{guessed_command_name} #{args.join(" ")}")
        end
      else
        super(symbol, *args)
      end
    end
    
    def push(value)
      # args can contain characters like '>' so we must escape them, but don't quote switches
      @args << ((value !~ /^[\+\-]/) ? "\"#{value}\"" : value.to_s.strip)
    end
    alias :<< :push

    def +(value)
      puts "MINI_MAGICK: The + command has been deprecated. Please use c << '+#{value}')"
      push "+#{value}"
    end
  end
end
