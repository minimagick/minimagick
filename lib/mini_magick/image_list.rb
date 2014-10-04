require "mini_magick/utilities"
require "pathname"

module MiniMagick
  class ImageList

    include Enumerable
    include MiniMagick::Utilities.array_methods(:images)

    def initialize(*images)
      @images = images
    end

    def each(&block)
      images.each(&block)
    end

    ##
    # Makes a `montage` of the image list, and returns the result image.
    # Accepts an optional extension.
    #
    # @param output_extension [String] Extension of the output image.
    # @yield [MiniMagick::Tool::Montage]
    # @return [MiniMagick::Image]
    # @see http://www.imagemagick.org/script/montage.php
    #
    def montage(output_extension = "jpg")
      output_tempfile = MiniMagick::Utilities.tempfile(output_extension)

      MiniMagick::Tool::Montage.new do |builder|
        yield builder if block_given?
        images.each { |image| builder << image.path }
        builder << output_tempfile.path
      end

      MiniMagick::Image.new(output_tempfile.path, output_tempfile)
    end

    ##
    # @return [MiniMagick::Image] Image is in GIF format.
    # @see http://www.imagemagick.org/script/command-line-options.php#coalesce
    #
    def coalesce(output_extension = "gif")
      output_tempfile = MiniMagick::Utilities.tempfile(output_extension)

      MiniMagick::Tool::Convert.new do |builder|
        images.each { |image| builder << image.path }
        builder.coalesce
        builder << output_tempfile.path
      end

      MiniMagick::Image.new(output_tempfile.path, output_tempfile)
    end

    ##
    # Formats the images into the specified format.
    #
    # @param format [String]
    # @return [MiniMagick::ImageList]
    #
    def format(format)
      MiniMagick::Tool::Convert
    end

    def method_missing(name, *args)
      mogrify do |builder|
        if builder.respond_to?(name)
          builder.send(name, *args)
        else
          super
        end
      end
    end

    private

    def mogrify
      images.each(&:clear_info)

      MiniMagick::Tool::Mogrify.new do |builder|
        builder.instance_eval do
          def format(*)
            fail NoMethodError,
              "you must call #format on a MiniMagick::ImageList directly"
          end
        end
        yield builder if block_given?
        images.each { |image| builder << image.path }
      end

      self
    end

    def images
      @images.map! do |input|
        case input
        when String, Pathname
          MiniMagick::Image.new(input)
        else
          input
        end
      end
    end

  end
end
