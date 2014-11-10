module MiniMagick
  class Image
    # @private
    class Info
      ASCII_ENCODED_EXIF_KEYS = %w[ExifVersion FlashPixVersion]

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
        when "signature"
          signature
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
            ASCII_ENCODED_EXIF_KEYS.each do |key|
              next unless hash.has_key?(key)

              value = hash[key]
              hash[key] = decode_comma_separated_ascii_characters(value)
            end
          end

          @info["exif"] = exif
        end
      end

      def raw(value)
        key = "raw:#{value}"
        @info.fetch(key) do
          @info[key] = identify { |b| b.format(value) }
        end
      end

      def signature
        @info.fetch("signature") do
          @info["signature"] = self["%#"]
        end
      end

      def identify
        MiniMagick::Tool::Identify.new do |builder|
          yield builder if block_given?
          builder << "#{@path}[0]"
        end
      end

      def decode_comma_separated_ascii_characters(encoded_value)
        return encoded_value unless encoded_value.include?(',')

        encoded_value.scan(/\d+/).map(&:to_i).map(&:chr).join
      end

    end
  end
end
