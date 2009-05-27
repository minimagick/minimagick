Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'mini_magick'
  s.version = "1.5"
  s.summary = "Manipulate images with minimal use of memory."
  s.description = %q{Uses command-line ImageMagick tools to resize, rotate, and mogrify images.}

  s.author = "Corey Johnson"
  s.email = "probablycorey@gmail.com"
  s.rubyforge_project = 'mini_magick'
  s.homepage = "http://github.com/probablycorey/mini_magick"

  s.has_rdoc = true
  s.requirements << 'none'
  s.require_path = 'lib'

  s.files = %w(.gitignore MIT-LICENSE README.rdoc Rakefile lib/image_temp_file.rb lib/mini_magick.rb mini_magick.gemspec test/actually_a_gif.jpg test/animation.gif test/command_builder_test.rb test/image_temp_file_test.rb test/image_test.rb test/leaves.tiff test/not_an_image.php test/simple.gif test/trogdor.jpg)
end
