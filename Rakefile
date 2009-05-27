require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

$:.unshift(File.dirname(__FILE__) + "/lib")
require 'mini_magick'

desc 'Default: run unit tests.'
task :default => :test

desc 'Clean generated files.'
task :clean => :clobber_rdoc do
  rm FileList['test/output/*.png']
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
  rdoc.options << '--line-numbers'
  rdoc.options << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Update gemspec.'
task :update_gemspec => :clean do
  files = `git-ls-files`.split
  data = File.read('mini_magick.gemspec')
  data.sub!(/^  s.version = .*$/, "  s.version = #{MiniMagick::VERSION.inspect}")
  data.sub!(/^  s.files = .*$/, "  s.files = %w(#{files.join(' ')})")
  open('mini_magick.gemspec', 'w'){|f| f.write(data)}
end
