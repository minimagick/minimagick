require 'spec_helper'

describe MiniMagick do
  context 'which util' do
    it "identifies when mogrify exists" do
      MiniMagick::Utilities.which("mogrify").should_not be_nil
    end

    it "identifies when gm exists" do
      MiniMagick::Utilities.which("gm").should_not be_nil
    end

    it "returns nil on nonexistent executables" do
      MiniMagick::Utilities.which("yogrify").should == nil
    end
  end

  context '.mogrify?' do
    it "checks if minimagick is using mogrify" do
      MiniMagick.processor = "mogrify"
      MiniMagick.mogrify?.should == true
    end

    it "checks if minimagick isn't using mogrify" do
      MiniMagick.processor = "gm"
      MiniMagick.mogrify?.should == false
    end

    it "sets the processor to mogrify (default) if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.mogrify?
      MiniMagick.processor.should == :mogrify
    end
  end

  context '.gm?' do
    it "checks if minimagick is using gm" do
      MiniMagick.processor = "gm"
      MiniMagick.gm?.should == true
    end

    it "checks if minimagick isn't using gm" do
      MiniMagick.processor = "mogrify"
      MiniMagick.gm?.should == false
    end

    it "sets the processor if it's not set" do
      MiniMagick.processor = nil
      MiniMagick.gm?
      MiniMagick.processor = "gm"
    end
  end

  its(:validate_on_create) { should be_true }
  its(:validate_on_write) { should be_true }
end
