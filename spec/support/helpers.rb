require "tempfile"

module Helpers
  def image_path(type = :default)
    if type != :jpg_without_extension
      File.join("spec/fixtures",
        case type
        when :default, :jpg       then "default.jpg"
        when :png                 then "engine.png"
        when :animation, :gif     then "animation.gif"
        when :exif                then "exif.jpg"
        when :empty_identify_line then "empty_identify_line.png"
        when :badly_encoded_line  then "badly_encoded_line.jpg"
        when :not                 then "not_an_image.rb"
        when :colon               then "with:colon.jpg"
        when :clipping_path       then "clipping_path.jpg"
        when :get_pixels          then "get_pixels.png"
        when :rgb                 then "rgb.png"
        when :rgb_tmp             then "rgb_tmp.png"
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

  def random_path(basename = "")
    @tempfile = Tempfile.open(basename)
    @tempfile.path
  end
end

RSpec.configure do |config|
  config.include Helpers
end

RSpec::Matchers.define :be_nonempty do
  match do |object|
    !object.empty?
  end
end
