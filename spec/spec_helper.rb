require "bundler/setup"
require "mini_magick"
require "pry"

require_relative "support/helpers"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.formatter = "documentation"
  config.color = true
  config.fail_fast = true unless ENV["CI"]

  [:imagemagick, :graphicsmagick].each do |cli|
    config.around(cli: cli) do |example|
      MiniMagick.with_cli(cli) { example.run }
    end
    config.around(skip_cli: cli) do |example|
      example.run unless example.metadata[:cli] == cli
    end
  end
end
