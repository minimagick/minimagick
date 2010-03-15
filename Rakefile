require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$:.unshift(File.dirname(__FILE__) + "/lib")
require 'mini_magick'

desc 'Default: run unit tests.'
task :default => :test

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
  rdoc.options << '--line-numbers'
  rdoc.options << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "mini_magick"
    gemspec.summary = "Manipulate images with minimal use of memory."
    gemspec.email = "probablycorey@gmail.com"
    gemspec.homepage = "http://github.com/pkieltyka/mini_magick"
    gemspec.authors = ["Corey Johnson", "Peter Kieltyka"]
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end