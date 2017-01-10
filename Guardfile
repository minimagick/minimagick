# directories %w(app lib config test spec features) \
#  .select{|d| Dir.exists?(d) ? d : UI.warning("Directory #{d} does not exist")}

## Note: if you are using the `directories` clause above and you are not
## watching the project directory ('.'), then you will want to move
## the Guardfile to a watched dir and symlink it back, e.g.
#
#  $ mkdir config
#  $ mv Guardfile config/
#  $ ln -s config/Guardfile .
#
# and, you'll have to watch "config/Guardfile" instead of "Guardfile"
guard 'rspec', cmd: 'bundle exec rspec', all_after_pass: false do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/mini_magick/(.+)\.rb$})     { |m| "spec/mini_magick/#{m[1]}_spec.rb" }
end
