module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/stream.php
    #
    class Stream < MiniMagick::Tool

      def initialize
        super("stream")
      end

    end
  end
end
