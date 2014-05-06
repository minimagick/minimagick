module MiniMagick
  class CommandBuilder
    MOGRIFY_COMMANDS = %w{adaptive-blur adaptive-resize adaptive-sharpen adjoin affine alpha annotate antialias append attenuate authenticate auto-gamma auto-level auto-orient backdrop background bench bias black-point-compensation black-threshold blend blue-primary blue-shift blur border bordercolor borderwidth brightness-contrast cache caption cdl channel charcoal chop clamp clip clip-mask clip-path clone clut coalesce colorize colormap color-matrix colors colorspace combine comment compose composite compress contrast contrast-stretch convolve crop cycle debug decipher deconstruct define delay delete density depth descend deskew despeckle direction displace display dispose dissimilarity-threshold dissolve distort dither draw duplicate edge emboss encipher encoding endian enhance equalize evaluate evaluate-sequence extent extract family features fft fill filter flatten flip floodfill flop font foreground format frame function fuzz fx gamma gaussian-blur geometry gravity green-primary hald-clut help highlight-color iconGeometry iconic identify ift immutable implode insert intent interlace interpolate interline-spacing interword-spacing kerning label lat layers level level-colors limit linear-stretch linewidth liquid-rescale list log loop lowlight-color magnify map mask mattecolor median metric mode modulate monitor monochrome morph morphology mosaic motion-blur name negate noise normalize opaque ordered-dither orient page paint path pause pen perceptible ping pointsize polaroid poly posterize precision preview print process profile quality quantize quiet radial-blur raise random-threshold red-primary regard-warnings region remap remote render repage resample resize respect-parentheses reverse roll rotate sample sampling-factor scale scene screen seed segment selective-blur separate sepia-tone set shade shadow shared-memory sharpen shave shear sigmoidal-contrast silent size sketch smush snaps solarize sparse-color splice spread statistic stegano stereo stretch strip stroke strokewidth style subimage-search swap swirl synchronize taint text-font texture threshold thumbnail tile tile-offset tint title transform transparent transparent-color transpose transverse treedepth trim type undercolor unique-colors units unsharp update verbose version view vignette virtual-pixel visual watermark wave weight white-point white-threshold window window-group write}
    IMAGE_CREATION_OPERATORS = %w{canvas caption gradient label logo pattern plasma radial radient rose text tile xc }
    RESOURCES = %w{area disk file map memory thread time}  # identify -list resource

    def initialize(tool, *options)
      @tool = tool
      @args = []
      options.each { |arg| push(arg) }
      # gather limits
      @limits = {}

      # handle any limits at module level
      RESOURCES.each do |resource|
        value = MiniMagick.__send__(:"#{resource}_limit")
        if value
          @limits[resource]=value
        end
      end

    end

    def add_limit_cmd
      @limits.each_pair do |limit_name,limit_value|
        add_limit(limit_name, limit_value)
      end
    end

    def command

      com = "#{@tool} #{(limits + args).join(' ')} ".strip
      com = "#{MiniMagick.processor} #{com}" unless MiniMagick.mogrify?

      com = File.join MiniMagick.processor_path, com unless MiniMagick.processor_path.nil?
      com.strip
    end

    def escape_fn(str)
      if !MiniMagick::Utilities.windows?
        str.shellescape
      else
        Utilities.windows_escape(str)
      end
    end

    def args
      if !MiniMagick::Utilities.windows?
        @args.map(&:shellescape)
      else
        @args.map { |arg| Utilities.windows_escape(arg) }
      end
    end

    def limits
      @limits.to_a.map { |el| "-limit #{escape_fn(el[0].to_s)} #{escape_fn(el[1].to_s)}" }
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
        options[1] = Utilities.windows_escape(options[1]) if mogrify_command == 'annotate'
        add_command(__method__.to_s.gsub("_","-"), *options)
        self
      end

      alias_method dashed_command, underscored_command
      alias_method "mogrify_#{underscored_command}", underscored_command
    end

    RESOURCES.each do |resource_name|
      underscored_command = "#{resource_name.to_s.gsub("-", "_")}_limit"
      define_method(underscored_command) do |*options|
        @limits[resource_name] = options[0] #add_command(__method__.to_s.gsub("_", "-"), *options)
        self
      end
    end

    def format(*options)
      raise Error, "You must call 'format' on the image object directly!"
    end

    IMAGE_CREATION_OPERATORS.each do |operator|
      define_method operator do |*options|
        add_creation_operator(__method__.to_s, *options)
        self
      end

      alias_method "operator_#{operator}", operator
    end

    (MOGRIFY_COMMANDS & IMAGE_CREATION_OPERATORS).each do |command_or_operator|
      define_method command_or_operator do |*options|
        if @tool == 'mogrify'
          method = self.method("mogrify_#{command_or_operator}")
        else
          method = self.method("operator_#{command_or_operator}")
        end
        method.call(*options)
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

    def add_limit(limit_name, value)
      push "-limit #{limit_name} #{value}"
    end

    def push(arg)
      @args << arg.to_s.strip
    end
    alias :<< :push
  end
end
