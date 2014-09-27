module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/conjure.php
    #
    class Conjure < MiniMagick::Tool

      def initialize
        super("conjure")
      end

    end
  end
end
