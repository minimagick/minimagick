require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

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
