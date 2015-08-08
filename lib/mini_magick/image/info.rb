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
        when "format", "width", "height", "dimensions", "size", "human_size"
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
        when "details"
          details
        else
          raw(value)
        end
      end

      def clear
        @info.clear
      end

      def cheap_info(value)
        @info.fetch(value) do
          format, width, height, size = self["%m %w %h %b"].split(" ")

          @info.update(
            "format"     => format,
            "width"      => Integer(width),
            "height"     => Integer(height),
            "dimensions" => [Integer(width), Integer(height)],
            "size"       => File.size(@path),
            "human_size" => size,
          )

          @info.fetch(value)
        end
      rescue ArgumentError, TypeError
        raise MiniMagick::Invalid, "image data can't be read"
      end

      def colorspace
        @info["colorspace"] ||= self["%r"]
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
        @info["exif"] ||= (
          output = self["%[EXIF:*]"]
          pairs = output.gsub(/^exif:/, "").split("\n").map { |line| line.split("=") }
          Hash[pairs].tap do |hash|
            ASCII_ENCODED_EXIF_KEYS.each do |key|
              next unless hash.has_key?(key)

              value = hash[key]
              hash[key] = decode_comma_separated_ascii_characters(value)
            end
          end
        )
      end

      def raw(value)
        @info["raw:#{value}"] ||= identify { |b| b.format(value) }
      end

      def signature
        @info["signature"] ||= self["%#"]
      end

      def details
        @info["details"] ||= (
          details_string = identify(&:verbose)
          key_stack = []
          details_string.lines.to_a[1..-1].each_with_object({}) do |line, details_hash|
            level = line[/^\s*/].length / 2 - 1
            next if level == -1 # we ignore the root level
            key_stack.pop until key_stack.size <= level

            key, _, value = line.partition(/:[\s\n]/).map(&:strip)
            hash = key_stack.inject(details_hash) { |hash, key| hash.fetch(key) }
            if value.empty?
              hash[key] = {}
              key_stack.push key
            else
              hash[key] = value
            end
          end
        )
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
