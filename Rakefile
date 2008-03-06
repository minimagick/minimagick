require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'

$:.unshift(File.dirname(__FILE__) + "/lib")
require 'mini_magick'

PKG_NAME      = 'mini_magick'
PKG_VERSION   = MiniMagick::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

desc 'Default: run unit tests.'
task :default => :test

desc "Clean generated files"
task :clean do
  rm FileList['test/output/*.png']
  rm_rf 'pkg'
  rm_rf 'doc'
end

desc 'Test the mini_magick plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the mini_magick plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'MiniMagick'
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end


# Create compressed packages
spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = PKG_NAME
  s.summary = "Manipulate images with minimal use of memory."
  s.description = %q{Uses command-line ImageMagick tools to resize, rotate, and mogrify images.}
  s.version = PKG_VERSION

  s.author = "Corey Johnson"
  s.email = "probablycorey@gmail.com"
  s.rubyforge_project = PKG_NAME
  s.homepage = "http://gleepglop.com"

  s.has_rdoc = true
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'mini_magick'

  s.files = [ "Rakefile", "README", "MIT-LICENSE" ]
  s.files = s.files + Dir.glob( "lib/**/*" ).delete_if { |item| item.include?( "\.svn" ) }
  s.files = s.files + Dir.glob( "test/**/*" ).delete_if { |item| item.include?( "\.svn" ) || item.include?("\.png") }
end
  
Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = false
  p.need_zip = true
end
