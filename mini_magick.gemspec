# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)

require 'mini_magick/version'

Gem::Specification.new do |s|
  s.name        = 'mini_magick'
  s.version     = MiniMagick::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Manipulate images with minimal use of memory via ImageMagick / GraphicsMagick'
  s.description = 'Manipulate images with minimal use of memory via ImageMagick / GraphicsMagick'
  s.requirements << 'You must have ImageMagick or GraphicsMagick installed'
  s.licenses    = ['MIT']

  s.authors     = ['Corey Johnson', 'Hampton Catlin', 'Peter Kieltyka', 'James Miller', 'Thiago Fernandes Massa']
  s.email       = ['probablycorey@gmail.com', 'hcatlin@gmail.com', 'peter@nulayer.com', 'bensie@gmail.com', 'thiagown@gmail.com']
  s.homepage    = 'https://github.com/minimagick/minimagick'

  s.files        = Dir['README.rdoc', 'VERSION', 'MIT-LICENSE', 'Rakefile', 'lib/**/*']
  s.test_files   = Dir['spec/**/*']
  s.require_paths = ['lib']
  s.add_runtime_dependency('subexec', ['~> 0.2.1'])

  s.add_development_dependency('rake')
  s.add_development_dependency('test-unit')
  s.add_development_dependency('rspec', ['~> 3.0.0'])
  s.add_development_dependency('mocha')
end
