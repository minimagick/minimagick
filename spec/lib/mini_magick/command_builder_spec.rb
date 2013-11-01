require 'spec_helper'

describe MiniMagick::CommandBuilder do
  before(:each) do
    @processor = MiniMagick.processor
    @processor_path = MiniMagick.processor_path
  end

  after(:each) do
    MiniMagick.processor_path = @processor_path
    MiniMagick.processor = @processor
  end

  let(:builder){ MiniMagick::CommandBuilder.new('test') }

  it "should build a basic command" do
    builder.resize "30x40"
    '-resize 30x40'.should == builder.args.join(" ")
  end
end
