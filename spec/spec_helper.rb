require 'rspec'
require 'mocha/api'

Dir.glob("lib/**/*.rb").each do |file|
  require_relative "../#{file}"
end

RSpec.configure do |config|
  config.mock_framework = :mocha
  config.color_enabled = true
  config.formatter     = 'documentation'
end
