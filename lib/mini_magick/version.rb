module MiniMagick
  ##
  # @return [Gem::Version]
  #
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 4
    MINOR = 2
    TINY  = 9
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
