require "tmpdir"

module Helpers
  def image_path(type = :default)
    File.join("spec/fixtures",
      case type
      when :default, :jpg   then "default.jpg"
      when :animation, :gif then "animation.gif"
      when :exif            then "exif.jpg"
      when :not             then "not_an_image.rb"
      end
    )
  end

  def image_url
    "https://assets-cdn.github.com/images/modules/logos_page/Octocat.png"
  end

  def random_path(basename = "")
    Dir::Tmpname.create(basename) {}
  end
end

RSpec.configure do |config|
  config.include Helpers
end
