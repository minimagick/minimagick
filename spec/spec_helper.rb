require "bundler/setup"
require "mini_magick"

require_relative "support/helpers"

MiniMagick.cli = :graphicsmagick if ENV["GM"]

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.formatter = "documentation"
  config.color = true
  config.fail_fast = true unless ENV["CI"]
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end
