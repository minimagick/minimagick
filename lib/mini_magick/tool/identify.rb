module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/identify.php
    #
    class Identify < MiniMagick::Tool

      def initialize
        super("identify")
      end

    end
  end
end
