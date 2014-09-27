module MiniMagick
  class Image
    class Info

      def initialize(path)
        @path = path
        @info = {}
      end

      def [](value, *args)
        case value
        when "format", "width", "height", "dimensions", "size"
          cheap_info(value)
        when "colorspace"
          colorspace
        when "mime_type"
          mime_type
        when "resolution"
          resolution(*args)
        when /^EXIF\:/i
          raw_exif(value)
        when "exif"
          exif
        else
          raw(value)
        end
      end

      def clear
        @info.clear
      end

      private

      def cheap_info(value)
        @info.fetch(value) do
          format, width, height, size = self["%m %w %h %b"].split(" ")

          @info.update(
            "format"     => format,
            "width"      => Integer(width),
            "height"     => Integer(height),
            "dimensions" => [Integer(width), Integer(height)],
            "size"       => size.to_i,
          )

          @info.fetch(value)
        end
      end

      def colorspace
        @info.fetch("colorspace") do
          @info["colorspace"] = self["%r"]
        end
      end

      def mime_type
        "image/#{self["format"].downcase}"
      end

      def resolution(unit = nil)
        output = identify do |b|
          b.units unit if unit
          b.format "%x %y"
        end
        output.split(" ").map(&:to_i)
      end

      def raw_exif(value)
        self["%[#{value}]"]
      end

      def exif
        @info.fetch("exif") do
          output = self["%[EXIF:*]"]
          pairs = output.gsub(/^exif:/, "").split("\n").map { |line| line.split("=") }
          exif = Hash[pairs].tap do |hash|
            hash.each do |key, value|
              if value.include?(",")
                # Sometimes exif comes in a comma-separated list of character values
                hash[key] = value.scan(/\d+/).map(&:to_i).map(&:chr).join
              end
            end
          end

          @info["exif"] = exif
        end
      end

      def raw(value)
        identify { |b| b.format(value) }
      end

      def identify
        MiniMagick::Tool::Identify.new do |builder|
          yield builder if block_given?
          builder << "#{@path}[0]"
        end
      end

    end
  end
end
