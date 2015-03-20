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
        when "details"
          details
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
          details_string.each_line.with_object([]).inject({}) do |details_hash, (line, key_stack)|
            level = line[/^\s*/].length / 2 - 1
            next details_hash if level == -1 # we ignore the root level
            hash = key_stack.inject(details_hash) { |hash, key| hash.fetch(key) }
            key, value = line.split(":", 2).map(&:strip)

            if level == key_stack.size
              if value.empty?
                hash[key] = {}
                key_stack.push key
              else
                hash[key] = value
              end
            elsif level < key_stack.size
              key_stack.pop
            end

            details_hash
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
