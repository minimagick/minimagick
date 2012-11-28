require 'test_helper'
require 'ostruct'

class MiniMagickTest < Test::Unit::TestCase
  include MiniMagick
  include MiniMagickTestFiles

  def setup
    @original_system_method = MiniMagick.system_method
    @original_timeout       = MiniMagick.timeout
  end

  def teardown
    MiniMagick.system_method = @original_system_method
    MiniMagick.timeout       = @original_timeout
  end

  def test_executes_custom_system_method
    block_run = false
    image     = Image.new(SIMPLE_IMAGE_PATH).tap(&:destroy!)

    MiniMagick.system_method = lambda do |command, timeout|
      block_run = true
      OpenStruct.new :output => '', :exitstatus => 0
    end

    image.run CommandBuilder.new('identify')
    assert block_run, 'system method not executed'
  end

  def test_passes_timeout_to_system_method
    image = Image.new(SIMPLE_IMAGE_PATH).tap(&:destroy!)

    MiniMagick.timeout = 42
    MiniMagick.system_method = lambda do |command, timeout|
      assert_equal 42, timeout
      OpenStruct.new :output => '', :exitstatus => 0
    end

    image.run CommandBuilder.new('identify')
  end
end
