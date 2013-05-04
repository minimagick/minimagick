require 'test_helper'
require 'digest/md5'

#MiniMagick.processor = :gm

class ImageTest < Test::Unit::TestCase
  include MiniMagick
  include MiniMagickTestFiles

  def test_image_from_blob
    File.open(SIMPLE_IMAGE_PATH, "rb") do |f|
      image = Image.read(f.read)
      assert image.valid?
      image.destroy!
    end
  end

  def test_image_from_tempfile
    tempfile = Tempfile.new('magick')

    File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
      tempfile.write(f.read)
      tempfile.rewind
    end

    image = Image.read(tempfile)
    assert image.valid?
    image.destroy!
  end

  def test_image_open
    image = Image.open(SIMPLE_IMAGE_PATH)
    assert image.valid?
    image.destroy!
  end

  def test_image_io_reading
#    buffer = StringIO.new(File.read(SIMPLE_IMAGE_PATH)) #This way does not work properly on windows
    buffer = StringIO.new File.open(SIMPLE_IMAGE_PATH,"rb") { |f| f.read } #This way works the same on all platforms
    image = Image.read(buffer)
    assert image.valid?
    image.destroy!
  end

  def test_image_create
    image = Image.create do |f|
      #Had to replace the old File.read with the following to work across all platforms
      f.write(File.open(SIMPLE_IMAGE_PATH,"rb") { |f| f.read })
    end
    image.destroy!
  end

  def test_image_new
    image = Image.new(SIMPLE_IMAGE_PATH)
    image.destroy!
  end

  def test_remote_image
    image = Image.open("http://upload.wikimedia.org/wikipedia/en/b/bc/Wiki.png")
    assert image.valid?
    image.destroy!
  end

  def test_remote_image_with_complex_url
    image = Image.open("http://a0.twimg.com/a/1296609216/images/fronts/logo_withbird_home.png?extra=foo&plus=bar")
    assert image.valid?
    image.destroy!
  end

  def test_reformat_with_capitalized_extension
    image = Image.open(CAP_EXT_PATH)
    image.format "jpg"
  end

  def test_image_write
    output_path = "output.gif"
    begin
      image = Image.new(SIMPLE_IMAGE_PATH)
      image.write output_path

      assert File.exists?(output_path)
    ensure
      File.delete output_path
    end
    image.destroy!
  end

  def test_image_write_with_space_in_output_path
    output_path = "test output.gif"
    begin
      image = Image.new(SIMPLE_IMAGE_PATH)
      image.write output_path

      assert File.exists?(output_path)
    ensure
      File.delete output_path
    end
    image.destroy!
  end

  def test_image_write_with_stream
    stream = StringIO.new
    image = Image.open(SIMPLE_IMAGE_PATH)
    image.write("#{Dir.tmpdir}/foo.gif")
    image.write(stream)
#    assert Image.read(stream.string).valid?
    image.destroy!
  end

  def test_not_an_image
    image = Image.new(NOT_AN_IMAGE_PATH)
    assert_equal false, image.valid?
    image.destroy!
  end

  def test_throw_on_opening_not_an_image
    assert_raise(MiniMagick::Invalid) do
      image = Image.open(NOT_AN_IMAGE_PATH)
      image.destroy
    end
  end

  def test_image_meta_info
    image = Image.new(SIMPLE_IMAGE_PATH)
    assert_equal 150, image[:width]
    assert_equal 55, image[:height]
    assert_equal [150, 55], image[:dimensions]
    assert_true String == image[:colorspace].class
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end

  def test_erroneous_image_meta_info
    image = Image.new(ERRONEOUS_IMAGE_PATH)
    assert_equal 10, image[:width]
    assert_equal 10, image[:height]
    assert_equal [10, 10], image[:dimensions]
    assert_equal('JPEG', image[:format])
    image.destroy!
  end

  def test_tiff
    image = Image.new(TIFF_IMAGE_PATH)
    assert_equal "tiff", image[:format].to_s.downcase
    assert_equal 50, image[:width]
    assert_equal 41, image[:height]
    image.destroy!
  end

  def test_gif_with_jpg_format
    image = Image.new(GIF_WITH_JPG_EXT)
    assert_equal "gif", image[:format].to_s.downcase
    image.destroy!
  end

  def test_image_resize
    image = Image.open(SIMPLE_IMAGE_PATH)
    image.resize "20x30!"

    assert_equal 20, image[:width]
    assert_equal 30, image[:height]
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end

  def test_image_resize_with_minimum
    image = Image.open(SIMPLE_IMAGE_PATH)
    original_width, original_height = image[:width], image[:height]
    image.resize "#{original_width + 10}x#{original_height + 10}>"

    assert_equal original_width, image[:width]
    assert_equal original_height, image[:height]
    image.destroy!
  end

  def test_image_combine_options_resize_blur
    image = Image.open(SIMPLE_IMAGE_PATH)
    image.combine_options do |c|
      c.resize "20x30!"
      c.blur "50"
    end

    assert_equal 20, image[:width]
    assert_equal 30, image[:height]
    assert_match(/^gif$/i, image[:format])
    image.destroy!
  end

  def test_image_combine_options_with_filename_with_minusses_in_it
    image = Image.open(SIMPLE_IMAGE_PATH)
    background = "#000000"
    assert_nothing_raised do
      image.combine_options do |c|
        c.draw "image Over 0,0 10,10 '#{MINUS_IMAGE_PATH}'"
        c.thumbnail "300x500>"
        c.background background
      end
    end
    image.destroy!
  end

  def test_image_combine_options_with_filename_with_special_characters_in_it
    image = Image.new(SPECIAL_CHARS_IMAGE_PATH)
    assert_nothing_raised do
      image.combine_options("identify") do |c|
        c.ping
      end
    end
    image.destroy!
  end

  def test_exif
    image = Image.open(EXIF_IMAGE_PATH)
    assert_equal('0220', image["exif:ExifVersion"])
    image = Image.open(SIMPLE_IMAGE_PATH)
    assert_equal('', image["EXIF:ExifVersion"])
    image.destroy!
  end

  def test_original_at
    image = Image.open(EXIF_IMAGE_PATH)
    assert_equal(Time.local('2005', '2', '23', '23', '17', '24'), image[:original_at])
    image = Image.open(SIMPLE_IMAGE_PATH)
    assert_nil(image[:original_at])
    image.destroy!
  end

  def test_tempfile_at_path
    image = Image.open(TIFF_IMAGE_PATH)
    assert_equal image.path, image.instance_eval("@tempfile.path")
    image.destroy!
  end

  def test_tempfile_at_path_after_format
    image = Image.open(TIFF_IMAGE_PATH)
    image.format('png')
    assert File.exists?(image.path)
    image.destroy!
  end

  def test_previous_tempfile_deleted_after_format
    image = Image.open(TIFF_IMAGE_PATH)
    before = image.path.dup
    image.format('png')
    assert !File.exist?(before)
    image.destroy!
  end

  def test_change_format_of_image_with_special_characters
    tempfile = Tempfile.new('magick with special! "chars\'')

    File.open(SIMPLE_IMAGE_PATH, 'rb') do |f|
      tempfile.write(f.read)
      tempfile.rewind
    end

    image = Image.new(tempfile.path)
    image.format('png')
    assert File.exists?(image.path)
    image.destroy!

    File.delete(image.path)
    tempfile.unlink
  end

  def test_bad_method_bug
    image = Image.open(TIFF_IMAGE_PATH)
    begin
      image.to_blog
    rescue NoMethodError
      assert true
    end
    image.to_blob
    assert true #we made it this far without error
    image.destroy!
  end

  def test_simple_composite
    if MiniMagick.valid_version_installed?
      image = Image.open(EXIF_IMAGE_PATH)
      result = image.composite(Image.open(TIFF_IMAGE_PATH)) do |c|
        c.gravity "center"
      end
      assert_true File.exists?(result.path)
    else
      puts "Need at least version #{MiniMagick.minimum_image_magick_version} of ImageMagick"
    end
  end

  # http://github.com/probablycorey/mini_magick/issues#issue/8
  def test_issue_8
    image = Image.open(SIMPLE_IMAGE_PATH)
    assert_nothing_raised do
      image.combine_options do |c|
        c.sample "50%"
        c.rotate "-90>"
      end
    end
    image.destroy!
  end

  # http://github.com/probablycorey/mini_magick/issues#issue/15
  def test_issue_15
    image = Image.open(Pathname.new(SIMPLE_IMAGE_PATH))
    output = Pathname.new("test.gif")
    image.write(output)
  ensure
    FileUtils.rm("test.gif")
  end

  # https://github.com/probablycorey/mini_magick/issues/37
  def test_nonstandard_locale
    original_lang = ENV["LANG"]
    ENV["LANG"] = "fr_FR.UTF-8"

    # This test should break
    test_throw_on_opening_not_an_image
  ensure
    ENV["LANG"] = original_lang
  end

  def test_poop
    img = MiniMagick::Image.open(SIMPLE_IMAGE_PATH)
    img.gravity "Center"
    img.crop "480x480"
    img.resize "250x250"
    img.write "#{Dir.tmpdir}/output.png"
  end

  def test_throw_format_error
    image = Image.open(SIMPLE_IMAGE_PATH)
    assert_raise MiniMagick::Error do
      image.combine_options do |c|
        c.format "png"
      end
    end
    image.destroy!
  end

  def test_import_pixels_default_format
    columns = 325
    rows = 200
    depth = 16 # 16 bits (2 bytes) per pixel
    map = 'gray'
    pixels = Array.new(columns*rows) {|i| i}
    blob = pixels.pack("S*") # unsigned short, native byte order
    image = Image.import_pixels(blob, columns, rows, depth, map)
    assert image.valid?
    assert_equal "png", image[:format].to_s.downcase
    assert_equal columns, image[:width]
    assert_equal rows, image[:height]
    image.write("#{Dir.tmpdir}/imported_pixels_image.png")
  end

  def test_import_pixels_custom_format
    columns = 325
    rows = 200
    depth = 16 # 16 bits (2 bytes) per pixel
    map = 'gray'
    format = 'jpeg'
    pixels = Array.new(columns*rows) {|i| i}
    blob = pixels.pack("S*") # unsigned short, native byte order
    image = Image.import_pixels(blob, columns, rows, depth, map, format)
    assert image.valid?
    assert_equal format, image[:format].to_s.downcase
    assert_equal columns, image[:width]
    assert_equal rows, image[:height]
    image.write("#{Dir.tmpdir}/imported_pixels_image." + format)
  end

  def test_mime_type
    gif =         Image.open(SIMPLE_IMAGE_PATH)
    jpeg =        Image.open(EXIF_IMAGE_PATH)
    png =         Image.open(PNG_PATH)
    tiff =        Image.open(TIFF_IMAGE_PATH)
    hidden_gif =  Image.open(GIF_WITH_JPG_EXT)

    assert_equal "image/gif",   gif.mime_type
    assert_equal "image/jpeg",  jpeg.mime_type
    assert_equal "image/png",   png.mime_type
    assert_equal "image/tiff",  tiff.mime_type
    assert_equal "image/gif",   hidden_gif.mime_type
  end
end
