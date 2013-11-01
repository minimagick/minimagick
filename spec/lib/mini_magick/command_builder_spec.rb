require 'spec_helper'

# All tests tagged as `ported` are ported from
# testunit tests and are there for backwards compatibility

MiniMagick.processor = '' #TODO: This should point to mogrify instead

describe MiniMagick::CommandBuilder do
  before(:each) do
    @processor = MiniMagick.processor
    @processor_path = MiniMagick.processor_path
  end

  after(:each) do
    MiniMagick.processor_path = @processor_path
    MiniMagick.processor = @processor
  end

  describe "ported from testunit", ported: true do
    let(:builder){ MiniMagick::CommandBuilder.new('test') }

    it "builds a basic command" do
      builder.resize "30x40"
      builder.args.join(" ").should == '-resize 30x40'
    end

    it "builds a full command" do
      builder.resize "30x40"
      builder.command.should == "test -resize 30x40"
    end

    it "builds a complicated command" do
      builder.resize "30x40"
      builder.alpha '1 3 4'
      builder.resize 'mome fingo'
      builder.args.join(" ").should == '-resize 30x40 -alpha 1\ 3\ 4 -resize mome\ fingo'
    end
  end
end
