module MiniMagick
  ##
  # Returns the version of the currently loaded MiniMagick as
  # a <tt>Gem::Version</tt>.
  def self.version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 3
    MINOR = 8
    TINY  = 0
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
