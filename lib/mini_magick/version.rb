module MiniMagick
  ##
  # @return [Gem::Version]
  #
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 4
    MINOR = 9
    TINY  = 4
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
