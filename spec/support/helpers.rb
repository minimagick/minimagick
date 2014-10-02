require "tempfile"

module Helpers
  def image_path(type = :default)
    if type != :without_extension
      File.join("spec/fixtures",
        case type
        when :default, :jpg   then "default.jpg"
        when :animation, :gif then "animation.gif"
        when :pdf             then "document.pdf"
        when :psd             then "image.psd"
        when :exif            then "exif.jpg"
        when :not             then "not_an_image.rb"
        else
          fail "image #{type.inspect} doesn't exist"
        end
      )
    else
      path = random_path
      FileUtils.cp image_path, path
      path
    end
  end

  def image_url
    "https://avatars2.githubusercontent.com/u/795488?v=2&s=40"
  end

  def random_path(basename = "")
    Tempfile.open(basename).path
  end
end

RSpec.configure do |config|
  config.include Helpers
end
