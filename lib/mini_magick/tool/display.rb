module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/display.php
    #
    class Display < MiniMagick::Tool

      def initialize
        super("display")
      end

    end
  end
end
