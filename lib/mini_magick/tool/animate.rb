module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/animate.php
    #
    class Animate < MiniMagick::Tool

      def initialize
        super("animate")
      end

    end
  end
end
