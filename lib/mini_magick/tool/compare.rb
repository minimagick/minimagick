module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/compare.php
    #
    class Compare < MiniMagick::Tool

      def initialize
        super("compare")
      end

    end
  end
end
