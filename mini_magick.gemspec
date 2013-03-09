# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "mini_magick/version"

Gem::Specification.new do |s|
  s.name        = "mini_magick"
  s.version     = MiniMagick::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "Manipulate images with minimal use of memory via ImageMagick / GraphicsMagick"
  s.description = ""
  s.requirements << "You must have ImageMagick or GraphicsMagick installed"

  s.authors     = ["Corey Johnson", "Hampton Catlin", "Peter Kieltyka"]
  s.email       = ["probablycorey@gmail.com", "hcatlin@gmail.com", "peter@nulayer.com"]
  s.homepage    = "https://github.com/minimagick/minimagick"

  s.files        = Dir['README.rdoc', 'VERSION', 'MIT-LICENSE', 'Rakefile', 'lib/**/*']
  s.test_files   = Dir['test/**/*']
  s.require_paths = ["lib"]
  s.add_runtime_dependency('subexec', ['~> 0.2.1'])

  s.add_development_dependency('rake')
  s.add_development_dependency('test-unit')
end
