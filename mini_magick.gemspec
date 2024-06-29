# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('../lib', __FILE__)

require 'mini_magick/version'

Gem::Specification.new do |s|
  s.name        = 'mini_magick'
  s.version     = MiniMagick.version
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Manipulate images with minimal use of memory via ImageMagick'
  s.description = 'Manipulate images with minimal use of memory via ImageMagick'
  s.requirements << 'You must have ImageMagick installed'
  s.licenses    = ['MIT']

  s.authors     = ['Corey Johnson',           'Hampton Catlin',    'Peter Kieltyka',    'James Miller',     'Thiago Fernandes Massa', 'Janko Marohnić']
  s.email       = ['probablycorey@gmail.com', 'hcatlin@gmail.com', 'peter@nulayer.com', 'bensie@gmail.com', 'thiagown@gmail.com',     'janko.marohnic@gmail.com']
  s.homepage    = 'https://github.com/minimagick/minimagick'

  s.files        = Dir['README.md', 'VERSION', 'MIT-LICENSE', 'Rakefile', 'lib/**/*']
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.3'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3.5.0'
  s.add_development_dependency 'webmock'

  s.metadata['changelog_uri'] = 'https://github.com/minimagick/minimagick/releases'
end
