require 'rake'
require 'rake/testtask'
begin
  # in 1.9
  require 'rdoc/task'
rescue LoadError
  # for 1.8 compat
  require 'rake/rdoctask'
end
require 'rubygems/package_task'

$:.unshift 'lib'

desc 'Default: run unit tests.'
task :default => [:print_version, :test]

task :print_version do 
  puts `mogrify --version`
end

desc 'Test the mini_magick plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = Dir.glob("test/**/*_test.rb")
  t.verbose = true
end

desc 'Generate documentation for the mini_magick plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'MiniMagick'
  rdoc.options << '--line-numbers'
  rdoc.options << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = eval(File.read('mini_magick.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
  pkg.need_zip = true
  pkg.need_tar = true
end
