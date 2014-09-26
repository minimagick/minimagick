require "tmpdir"

module Helpers
  IMAGE_DIR = "spec/fixtures"
  IMAGE_PATHS = {
    gif:              "simple.gif",
    not:              "not_an_image.php",
    gif_with_jpg_ext: "actually_a_gif.jpg",
    exif:             "trogdor.jpg",
    jpg:              "trogdor.jpg",
    capitalized_ext:  "trogdor_capitalized.JPG",
    animation:        "animation.gif",
    png:              "png.png",
    erroneous:        "erroneous.jpg",
    psd:              "layers.psd",
    single_layer_psd: "slayers.psd",
  }

  def image_path(type = :gif)
    File.join(IMAGE_DIR, IMAGE_PATHS.fetch(type))
  end

  def image_url
    "http://a0.twimg.com/a/1296609216/images/fronts/logo_withbird_home.png?extra=foo&plus=bar"
  end

  def random_path(basename = "")
    Dir::Tmpname.create(basename) {}
  end
end

RSpec.configure do |config|
  config.include Helpers
end
