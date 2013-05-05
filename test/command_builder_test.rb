require 'test_helper'

class CommandBuilderTest < Test::Unit::TestCase
  include MiniMagick

  def setup
    @processor_path = MiniMagick.processor_path
    @processor = MiniMagick.processor
    @strict_mode = MiniMagick.strict_mode
  end

  def teardown
    MiniMagick.processor_path = @processor_path
    MiniMagick.processor = @processor
    MiniMagick.strict_mode = @strict_mode
  end

  def test_basic
    c = CommandBuilder.new("test")
    c.resize "30x40"
    assert_equal '-resize 30x40', c.args.join(" ")
  end

  def test_full_command
    c = CommandBuilder.new("test")
    c.resize "30x40"
    assert_equal "test -resize 30x40", c.command
  end

  def test_complicated
    c = CommandBuilder.new("test")
    c.resize "30x40"
    c.alpha "1 3 4"
    c.resize "mome fingo"
    assert_equal '-resize 30x40 -alpha 1\ 3\ 4 -resize mome\ fingo', c.args.join(" ")
  end

  def test_plus_modifier_and_multiple_options
    c = CommandBuilder.new("test")
    c.distort.+ 'srt', '0.6 20'
    assert_equal '\+distort srt 0.6\ 20', c.args.join(" ")
  end

  def test_valid_command
    begin
      c = CommandBuilder.new("test", "path")
      c.input 2
      assert false
    rescue NoMethodError
      assert true
    end
  end

  def test_dashed
    c = CommandBuilder.new("test")
    c.auto_orient
    assert_equal "-auto-orient", c.args.join(" ")
  end

  def test_dashed_via_send
    c = CommandBuilder.new("test")
    c.send("auto-orient")
    assert_equal "-auto-orient", c.args.join(" ")
  end

  def test_canvas
    c = CommandBuilder.new('test')
    c.canvas 'black'
    assert_equal "canvas:black", c.args.join
  end

  def test_set
    c = CommandBuilder.new("test")
    c.set "colorspace RGB"
    assert_equal 'test -set colorspace\ RGB', c.command
  end

  def test_processor_path
    MiniMagick.processor_path = "/a/strange/path"
    c = CommandBuilder.new('test')
    c.auto_orient
    assert_equal c.command, "/a/strange/path/test -auto-orient"
  end

  def test_processor_path_with_processor
    MiniMagick.processor_path = "/a/strange/path"
    MiniMagick.processor = "processor"
    c = CommandBuilder.new('test')
    c.auto_orient
    assert_equal c.command, "/a/strange/path/processor test -auto-orient"
  end

  def test_valid_processor_path_in_strict_mode
    MiniMagick.strict_mode = true
    MiniMagick.processor_path = "test"
    c = CommandBuilder.new('identify')
    assert_equal c.command, "test/identify"
  end

  def test_invalid_processor_path_in_strict_mode
    MiniMagick.strict_mode = true
    MiniMagick.processor_path = "/a/stange/path"
    assert_raise MiniMagick::StrictModeError, "'/a/strange/path' is not a valid directory" do
      CommandBuilder.new('identify')
    end
  end

  def test_valid_processor_in_strict_mode
    MiniMagick.strict_mode = true
    MiniMagick.processor = "gm"
    c = CommandBuilder.new('identify')
    assert_equal c.command, "gm identify"
  end

  def test_invalid_processor_in_strict_mode
    MiniMagick.strict_mode = true
    MiniMagick.processor = "test"
    assert_raise MiniMagick::StrictModeError, "processor must be either nil or 'gm'" do
      CommandBuilder.new('identify')
    end
  end

  def test_valid_tool_in_strict_mode
    MiniMagick.strict_mode = true
    c = CommandBuilder.new('identify')
    assert_equal c.command, "identify"
  end

  def test_invalid_tool_in_strict_mode
    MiniMagick.strict_mode = true
    assert_raise MiniMagick::StrictModeError, "'test' is not in the list of allowed tools: convert, composite, identify, mogrify" do
      CommandBuilder.new('test')
    end
  end
end
