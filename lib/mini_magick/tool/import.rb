module MiniMagick
  class Tool
    ##
    # @see http://www.imagemagick.org/script/import.php
    #
    class Import < MiniMagick::Tool

      def initialize
        super("import")
      end

    end
  end
end
