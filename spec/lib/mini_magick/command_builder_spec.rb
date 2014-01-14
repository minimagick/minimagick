require 'spec_helper'

# All tests tagged as `ported` are ported from
# testunit tests and are there for backwards compatibility

MiniMagick.processor = 'mogrify'

describe MiniMagick::CommandBuilder do
  before(:each) do
    @processor = MiniMagick.processor
    @processor_path = MiniMagick.processor_path
  end

  after(:each) do
    MiniMagick.processor_path = @processor_path
    MiniMagick.processor = @processor
  end

  describe "ported from testunit", :ported => true do
    let(:builder){ MiniMagick::CommandBuilder.new('test') }

    it "builds a basic command" do
      builder.resize "30x40"
      builder.args.join(" ").should == '-resize 30x40'
    end

    it "builds a full command" do
      builder.resize "30x40"
      builder.command.should == "test -resize 30x40"
    end

    describe 'windows only', :if => MiniMagick::Utilities.windows? do
      it "builds a complicated command" do
        builder.resize "30x40"
        builder.alpha '1 3 4'
        builder.resize 'mome fingo'
        builder.args.join(" ").should == '-resize 30x40 -alpha 1 3 4 -resize mome fingo'
      end

      it "builds a command with multiple options and plus modifier" do
        builder.distort.+ 'srt', '0.6 20'
        builder.args.join(" ").should == '+distort srt 0.6 20'
      end

      it "sets a colorspace correctly" do
        builder.set 'colorspace RGB'
        builder.command.should == 'test -set colorspace RGB'
      end
    end

    describe 'not windows', :if => !MiniMagick::Utilities.windows? do
      it "builds a complicated command" do
        builder.resize "30x40"
        builder.alpha '1 3 4'
        builder.resize 'mome fingo'
        builder.args.join(" ").should == '-resize 30x40 -alpha 1\ 3\ 4 -resize mome\ fingo'
      end

      it "sets a colorspace correctly" do
        builder.set 'colorspace RGB'
        builder.command.should == 'test -set colorspace\ RGB'
      end

      it "builds a command with multiple options and plus modifier" do
        builder.distort.+ 'srt', '0.6 20'
        builder.args.join(" ").should == '\+distort srt 0.6\ 20'
      end
    end

    describe 'common verbs between morgify and image creation operators' do
      context 'mogrify' do
        let(:builder) {described_class.new('mogrify')}

        it 'builds the command' do
          builder.caption 'caption_text'
          builder.command.should == 'mogrify -caption caption_text'    
        end
      end

      context 'other' do
        it 'builds the command' do
          builder.caption 'caption_text'
          builder.command.should == 'test caption:caption_text'    
        end
      end
    end

    it "raises error when command is invalid" do
      expect do
        command = MiniMagick::CommandBuilder.new('test', 'path')
        command.input 2
      end.to raise_error(NoMethodError)
    end

    it "builds a dashed command" do
      builder.auto_orient
      builder.args.join(" ").should == '-auto-orient'
    end

    it "builds a dashed command via send" do
      builder.send('auto-orient')
      builder.args.join(' ').should == '-auto-orient'
    end

    it "builds a canvas command" do
      builder.canvas 'black'
      builder.args.join(' ').should == 'canvas:black'
    end

    it "sets a processor path correctly" do
      MiniMagick.processor_path = "/a/strange/path"
      builder.auto_orient
      builder.command.should == "/a/strange/path/test -auto-orient"
    end

    it "builds a processor path with processor" do
      MiniMagick.processor_path = "/a/strange/path"
      MiniMagick.processor = "processor"
      builder.auto_orient
      builder.command.should == "/a/strange/path/processor test -auto-orient"
    end
  end

  context 'deprecated' do
    let(:builder){ MiniMagick::CommandBuilder.new('test') }
    before(:each) { MiniMagick.processor = nil }

    it "builds a full command" do
      builder.resize "30x40"
      builder.command.should == "test -resize 30x40"
    end

    describe 'windows only', :if => MiniMagick::Utilities.windows? do
      it "sets a colorspace correctly" do
        builder.set 'colorspace RGB'
        builder.command.should == 'test -set colorspace RGB'
      end
    end

    describe 'not windows', :if => !MiniMagick::Utilities.windows? do
      it "sets a colorspace correctly" do
        builder.set 'colorspace RGB'
        builder.command.should == 'test -set colorspace\ RGB'
      end
    end

    it "sets a processor path correctly" do
      MiniMagick.processor_path = "/a/strange/path"
      builder.auto_orient
      builder.command.should == "/a/strange/path/test -auto-orient"
    end
  end
end
