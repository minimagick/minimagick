module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/convert.php
    #
    class Convert < MiniMagick::Tool

      def initialize
        super("convert")
      end

    end
  end
end
