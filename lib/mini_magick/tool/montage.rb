module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/montage.php
    #
    class Montage < MiniMagick::Tool

      def initialize
        super("montage")
      end

    end
  end
end
