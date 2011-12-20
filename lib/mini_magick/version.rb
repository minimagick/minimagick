module MiniMagick
  module VERSION
    unless defined? MAJOR
      MAJOR = 3
      MINOR = 4
      TINY = 0
      STRING = [MAJOR, MINOR, TINY].compact.join('.')
    end
  end
end