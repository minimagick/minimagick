require "bundler/setup"
require "mini_magick"

require_relative "support/helpers"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.formatter = "documentation"
  config.color = true
  config.fail_fast = true unless ENV["CI"]
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  [:imagemagick, :graphicsmagick].each do |cli|
    config.before(cli: cli) do |example|
      allow(MiniMagick).to receive(:cli).and_return(cli)
    end
    config.around(skip_cli: cli) do |example|
      example.run unless example.metadata[:cli] == cli
    end
  end
end
