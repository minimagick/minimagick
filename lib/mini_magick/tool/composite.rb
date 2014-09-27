module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/composite.php
    #
    class Composite < MiniMagick::Tool

      def initialize
        super("composite")
      end

    end
  end
end
