module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/mogrify.php
    #
    class Mogrify < MiniMagick::Tool

      def initialize
        super("mogrify")
      end

    end
  end
end
